package app.aura.pilot;

import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.Intent;
import android.net.Uri;
import android.os.Handler;
import android.os.Looper;
import com.solana.mobilewalletadapter.clientlib.protocol.MobileWalletAdapterClient;
import com.solana.mobilewalletadapter.clientlib.scenario.LocalAssociationIntentCreator;
import com.solana.mobilewalletadapter.clientlib.scenario.LocalAssociationScenario;
import java.util.concurrent.*;

/** Official MWA encrypted local association; no wallet keys or persistent MWA authorization tokens. */
final class NativeWallet {
    static final int REQUEST = 72;
    interface Work { org.json.JSONObject run(MobileWalletAdapterClient client) throws Exception; }
    interface Result { void complete(org.json.JSONObject result, Exception error); }
    private final Handler main = new Handler(Looper.getMainLooper());
    private final ExecutorService worker = Executors.newSingleThreadExecutor();
    private LocalAssociationScenario scenario;
    private Future<?> operation;
    private int generation;
    boolean busy() { return scenario != null; }
    void transact(Activity activity, Work work, Result result) {
        if (busy()) { result.complete(null, new IllegalStateException("Finish the current wallet request first.")); return; }
        final int run = ++generation;
        final LocalAssociationScenario current = new LocalAssociationScenario(90000); scenario = current;
        try {
            Intent intent = LocalAssociationIntentCreator.createAssociationIntent(null, current.getPort(), current.getSession());
            // startActivityForResult supplies the caller identity required by the MWA protocol.
            activity.startActivityForResult(intent, REQUEST);
            final Future<MobileWalletAdapterClient> connected = current.start();
            operation = worker.submit(() -> {
                org.json.JSONObject value = null; Exception error = null;
                try { value = work.run(connected.get(60, TimeUnit.SECONDS)); }
                catch (Exception e) { error = e instanceof ExecutionException && e.getCause() instanceof Exception ? (Exception)e.getCause() : e; }
                finally { current.close(); }
                final org.json.JSONObject output = value; final Exception failure = error;
                main.post(() -> { if (run != generation) return; scenario = null; operation = null; result.complete(output, failure); });
            });
        } catch (Exception e) {
            current.close(); scenario = null;
            result.complete(null, e instanceof ActivityNotFoundException ? new IllegalStateException("Install a wallet supporting Solana Mobile Wallet Adapter, or use browser pairing.") : e);
        }
    }
    static MobileWalletAdapterClient.AuthorizationResult authorize(MobileWalletAdapterClient client, String origin) throws Exception {
        return client.authorize(Uri.parse(origin), null, "Aura", "solana:devnet", null,
            new String[]{"solana:signMessages", "solana:signTransactions"}, null, null).get(90, TimeUnit.SECONDS);
    }
    void cancel() { generation++; if (scenario != null) scenario.close(); if (operation != null) operation.cancel(true); scenario = null; operation = null; }
    void close() { cancel(); worker.shutdownNow(); }
}
