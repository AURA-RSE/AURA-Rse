package app.aura.pilot;

import android.content.Context;
import android.content.SharedPreferences;
import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyProperties;
import android.util.Base64;
import java.nio.charset.StandardCharsets;
import java.security.KeyStore;
import java.security.MessageDigest;
import java.util.Arrays;
import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;

/** Only an encrypted API bearer token is persisted; wallet keys never enter this app. */
final class SecureSession {
    private static final String ALIAS = "aura.api.session.v1";
    private final SharedPreferences preferences;
    SecureSession(Context context) { preferences = context.getSharedPreferences("aura-sessions", Context.MODE_PRIVATE); }
    private String scope(String origin) throws Exception {
        return Base64.encodeToString(MessageDigest.getInstance("SHA-256").digest(origin.getBytes(StandardCharsets.UTF_8)), Base64.NO_WRAP);
    }
    private SecretKey key() throws Exception {
        KeyStore store = KeyStore.getInstance("AndroidKeyStore"); store.load(null);
        if (store.containsAlias(ALIAS)) return ((KeyStore.SecretKeyEntry) store.getEntry(ALIAS, null)).getSecretKey();
        KeyGenerator generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore");
        generator.init(new KeyGenParameterSpec.Builder(ALIAS, KeyProperties.PURPOSE_ENCRYPT | KeyProperties.PURPOSE_DECRYPT)
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build());
        return generator.generateKey();
    }
    synchronized void save(String origin, String token) throws Exception {
        Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding"); cipher.init(Cipher.ENCRYPT_MODE, key());
        byte[] encrypted = cipher.doFinal(token.getBytes(StandardCharsets.UTF_8));
        byte[] packed = new byte[cipher.getIV().length + encrypted.length];
        System.arraycopy(cipher.getIV(), 0, packed, 0, cipher.getIV().length);
        System.arraycopy(encrypted, 0, packed, cipher.getIV().length, encrypted.length);
        if (!preferences.edit().putString(scope(origin), Base64.encodeToString(packed, Base64.NO_WRAP)).commit())
            throw new IllegalStateException("Unable to save the encrypted device session.");
    }
    synchronized String read(String origin) throws Exception {
        String value = preferences.getString(scope(origin), null); if (value == null) return null;
        byte[] packed = Base64.decode(value, Base64.NO_WRAP);
        if (packed.length < 29) throw new IllegalStateException("Invalid encrypted session. Pair this device again.");
        Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
        cipher.init(Cipher.DECRYPT_MODE, key(), new GCMParameterSpec(128, Arrays.copyOfRange(packed, 0, 12)));
        return new String(cipher.doFinal(Arrays.copyOfRange(packed, 12, packed.length)), StandardCharsets.UTF_8);
    }
    synchronized void clear(String origin) throws Exception { if (!preferences.edit().remove(scope(origin)).commit()) throw new IllegalStateException("Unable to clear the device session."); }
}
