package app.aura.pilot;

import java.math.BigInteger;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.util.Arrays;

/** Strict decoder for Aura's one-signer, one-SystemProgram-transfer legacy transactions. */
final class SolanaWire {
    private static final String ALPHABET = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";
    private static final BigInteger RADIX = BigInteger.valueOf(58);
    static String base58(byte[] bytes) {
        BigInteger value = new BigInteger(1, bytes); StringBuilder out = new StringBuilder();
        while (value.signum() > 0) { BigInteger[] part = value.divideAndRemainder(RADIX); out.append(ALPHABET.charAt(part[1].intValue())); value = part[0]; }
        for (byte b : bytes) { if (b != 0) break; out.append('1'); }
        return out.reverse().toString();
    }
    static byte[] decode58(String text) {
        require(text != null && text.length() > 0 && text.length() <= 100, "Invalid base58 value");
        BigInteger value = BigInteger.ZERO; int zeroes = 0;
        for (int i = 0; i < text.length(); i++) { int digit = ALPHABET.indexOf(text.charAt(i)); require(digit >= 0, "Invalid base58 value"); value = value.multiply(RADIX).add(BigInteger.valueOf(digit)); }
        while (zeroes < text.length() && text.charAt(zeroes) == '1') zeroes++;
        byte[] raw = value.signum() == 0 ? new byte[0] : value.toByteArray(); int skip = raw.length > 0 && raw[0] == 0 ? 1 : 0;
        byte[] out = new byte[zeroes + raw.length - skip]; System.arraycopy(raw, skip, out, zeroes, raw.length - skip); return out;
    }
    static void validateUnsigned(byte[] transaction, String sender, String recipient, long lamports, String reference) {
        require(lamports > 0 && lamports <= 1_000_000_000L, "Amount outside devnet pilot limits");
        Reader r = new Reader(transaction); require(r.byteValue() == 1, "Expected one signature");
        for (byte b : r.take(64)) require(b == 0, "Expected an unsigned transaction");
        // Exactly one writable signer, one writable recipient, and two readonly unsigned keys.
        require(r.byteValue() == 1 && r.byteValue() == 0 && r.byteValue() == 2, "Unexpected transaction permissions");
        require(r.byteValue() == 4, "Unexpected account count");
        byte[][] keys = new byte[4][]; for (int i = 0; i < 4; i++) keys[i] = r.take(32);
        require(base58(keys[0]).equals(sender) && base58(keys[1]).equals(recipient), "Transaction changes the sender or recipient");
        for (int i = 0; i < 4; i++) for (int j = 0; j < i; j++) require(!Arrays.equals(keys[i], keys[j]), "Duplicate transaction account");
        r.take(32); // recent blockhash; expiry is checked by Solana, and the server supplies confirmed commitment.
        require(r.byteValue() == 1, "Expected exactly one instruction");
        int program = r.byteValue(); require(program >= 2 && program < 4 && Arrays.equals(keys[program], new byte[32]), "Only the System Program is allowed");
        require(r.byteValue() == 3 && r.byteValue() == 0 && r.byteValue() == 1, "Unexpected transfer accounts");
        int ref = r.byteValue(); require(ref >= 2 && ref < 4 && ref != program && base58(keys[ref]).equals(reference), "Payment reference changed");
        require(r.byteValue() == 12, "Unexpected instruction length");
        ByteBuffer data = ByteBuffer.wrap(r.take(12)).order(ByteOrder.LITTLE_ENDIAN);
        require(data.getInt() == 2 && data.getLong() == lamports, "Transaction changes the amount or operation");
        require(r.remaining() == 0, "Unexpected trailing transaction data");
    }
    static String verifySignedMessage(byte[] unsigned, byte[] signed) {
        require(signed != null && signed.length == unsigned.length && signed.length > 65 && signed[0] == 1, "Invalid signed transaction");
        require(Arrays.equals(Arrays.copyOfRange(unsigned, 65, unsigned.length), Arrays.copyOfRange(signed, 65, signed.length)), "Wallet changed the reviewed transaction");
        byte[] signature = Arrays.copyOfRange(signed, 1, 65);
        require(!Arrays.equals(signature, new byte[64]), "Wallet did not sign the transaction");
        // The server verifies Ed25519 cryptographically before any network submission.
        return base58(signature);
    }
    static void require(boolean condition, String message) { if (!condition) throw new IllegalArgumentException(message); }
    private static final class Reader {
        final byte[] bytes; int offset;
        Reader(byte[] bytes) { require(bytes != null && bytes.length <= 1232, "Invalid transaction size"); this.bytes = bytes; }
        int byteValue() { return take(1)[0] & 255; }
        byte[] take(int count) { require(count <= remaining(), "Truncated transaction"); byte[] result = Arrays.copyOfRange(bytes, offset, offset + count); offset += count; return result; }
        int remaining() { return bytes.length - offset; }
    }
}
