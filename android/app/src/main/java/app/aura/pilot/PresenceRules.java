package app.aura.pilot;

/** Platform-independent rules shared by the Android radio controller and local tests. */
public final class PresenceRules {
    private PresenceRules() { }
    public static boolean validToken(String token) { return token != null && token.matches("[A-Za-z0-9_-]{22}"); }
    public static boolean fresh(long seenAt, long expiresAt, long now) {
        return seenAt <= now && now - seenAt <= 15000 && expiresAt > now;
    }
    public static byte[] slice(byte[] value, int offset) {
        if (offset < 0 || offset > value.length) throw new IllegalArgumentException("Invalid ATT offset");
        return java.util.Arrays.copyOfRange(value, offset, value.length);
    }
}
