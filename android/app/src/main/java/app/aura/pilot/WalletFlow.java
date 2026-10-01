package app.aura.pilot;

import android.util.Base64;
import com.solana.mobilewalletadapter.clientlib.protocol.MobileWalletAdapterClient;
import java.nio.charset.StandardCharsets;
import java.util.Arrays;
import java.util.concurrent.TimeUnit;
import org.json.JSONObject;

/** Wallet proof and payment operations run off the UI thread, captured to one API origin/account. */
final class WalletFlow {
    private static String pendingScope(String origin, String wallet) { return "pending-payment:" + origin + ":" + wallet; }
    static JSONObject pending(SecureSession storage, String origin, String wallet) throws Exception {
        String value = storage.read(pendingScope(origin, wallet)); return value == null ? null : new JSONObject(value);
    }
    static JSONObject signIn(MobileWalletAdapterClient client, AuraApi api, String origin) throws Exception {
        var authorization = NativeWallet.authorize(client, origin);
        SolanaWire.require(authorization.accounts.length > 0, "Wallet returned no account");
        byte[] address = authorization.accounts[0].publicKey;
        SolanaWire.require(address.length == 32, "Invalid wallet address");
        JSONObject challenge = api.post("/api/auth/challenge", AuraApi.object("wallet", SolanaWire.base58(address)));
        byte[] message = challenge.getString("message").getBytes(StandardCharsets.UTF_8);
        var proof = client.signMessagesDetached(new byte[][]{message}, new byte[][]{address}).get(90, TimeUnit.SECONDS);
        SolanaWire.require(proof.messages.length == 1 && Arrays.equals(proof.messages[0].message, message)
            && proof.messages[0].addresses.length == 1 && Arrays.equals(proof.messages[0].addresses[0], address)
            && proof.messages[0].signatures.length == 1 && proof.messages[0].signatures[0].length == 64, "Wallet changed the sign-in proof");
        if (Thread.currentThread().isInterrupted()) throw new InterruptedException();
        return api.post("/api/auth/verify", AuraApi.object("id", challenge.getString("id"), "signature", Base64.encodeToString(proof.messages[0].signatures[0], Base64.NO_WRAP)));
    }
    static JSONObject pay(MobileWalletAdapterClient client, AuraApi api, SecureSession storage, String origin, String wallet, JSONObject reviewed) throws Exception {
        SolanaWire.require(pending(storage, origin, wallet) == null, "A signed payment needs recovery first. Open Activity.");
        var authorization = NativeWallet.authorize(client, origin); boolean match = false;
        for (var account : authorization.accounts) if (SolanaWire.base58(account.publicKey).equals(wallet)) match = true;
        SolanaWire.require(match, "Choose the wallet already verified in Aura. No payment was submitted.");
        JSONObject prepared = api.post("/api/payments/prepare", AuraApi.object("id", reviewed.getString("id")));
        SolanaWire.require("devnet".equals(prepared.getString("cluster")) && wallet.equals(prepared.getString("sender"))
            && reviewed.getString("recipient").equals(prepared.getString("recipient")) && reviewed.getLong("lamports") == prepared.getLong("lamports")
            && reviewed.getString("reference").equals(prepared.getString("reference")), "Prepared payment does not match your review");
        byte[] unsigned = Base64.decode(prepared.getString("transaction"), Base64.NO_WRAP);
        SolanaWire.validateUnsigned(unsigned, wallet, reviewed.getString("recipient"), reviewed.getLong("lamports"), reviewed.getString("reference"));
        if (Thread.currentThread().isInterrupted()) throw new InterruptedException();
        var result = client.signTransactions(new byte[][]{unsigned}).get(90, TimeUnit.SECONDS);
        SolanaWire.require(result.signedPayloads.length == 1, "Wallet returned an unexpected transaction count");
        String signature = SolanaWire.verifySignedMessage(unsigned, result.signedPayloads[0]);
        JSONObject saved = AuraApi.object("id", reviewed.getString("id"), "transaction", Base64.encodeToString(result.signedPayloads[0], Base64.NO_WRAP),
            "signature", signature, "recipient", reviewed.getString("recipient"), "lamports", reviewed.getLong("lamports"));
        // Persist before any submit call. A lost response or process death must not prompt a second signature.
        storage.save(pendingScope(origin, wallet), saved.toString());
        if (Thread.currentThread().isInterrupted()) throw new InterruptedException();
        return recover(api, storage, origin, wallet);
    }
    static JSONObject recover(AuraApi api, SecureSession storage, String origin, String wallet) throws Exception {
        JSONObject saved = pending(storage, origin, wallet);
        SolanaWire.require(saved != null, "No signed payment is waiting for recovery");
        JSONObject proof = AuraApi.object("id", saved.getString("id"), "signature", saved.getString("signature"));
        JSONObject checked = api.post("/api/payments/confirm", proof);
        if (!"confirmed".equals(checked.optString("state"))) {
            // Re-send the identical signed bytes. Never ask the wallet to sign again for this intent.
            JSONObject sent = api.post("/api/payments/submit", AuraApi.object("id", saved.getString("id"), "transaction", saved.getString("transaction")));
            SolanaWire.require(saved.getString("signature").equals(sent.getString("signature")), "Server reports another signature; stop and review wallet history");
            checked = api.post("/api/payments/confirm", proof);
        }
        if ("confirmed".equals(checked.optString("state"))) storage.clear(pendingScope(origin, wallet));
        return AuraApi.object("state", checked.getString("state"), "signature", saved.getString("signature"));
    }
}
