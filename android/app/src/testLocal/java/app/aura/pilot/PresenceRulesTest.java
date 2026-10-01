package app.aura.pilot;
import java.nio.charset.StandardCharsets;
import java.util.Arrays;
public final class PresenceRulesTest {
    private static int assertions;
    private static void check(boolean valid) { assertions++;if(!valid)throw new AssertionError("Check "+assertions+" failed"); }
    public static void main(String[] args) {
        check(PresenceRules.validToken("AbCdEfGhIjKlMnOpQrStUv"));
        check(!PresenceRules.validToken(null));check(!PresenceRules.validToken("wallet-name"));
        check(!PresenceRules.validToken("AbCdEfGhIjKlMnOpQrStU+"));
        check(!PresenceRules.validToken("AbCdEfGhIjKlMnOpQrStUv="));
        check(PresenceRules.fresh(1000,20000,16000));check(!PresenceRules.fresh(1000,20000,16001));
        check(!PresenceRules.fresh(1000,15000,15000));check(!PresenceRules.fresh(20000,30000,10000));
        byte[] bytes="AbCdEfGhIjKlMnOpQrStUv".getBytes(StandardCharsets.UTF_8);
        check(Arrays.equals(bytes,PresenceRules.slice(bytes,0)));check(PresenceRules.slice(bytes,22).length==0);
        check(new String(PresenceRules.slice(bytes,20),StandardCharsets.UTF_8).equals("Uv"));
        boolean rejected=false;try{PresenceRules.slice(bytes,23);}catch(IllegalArgumentException e){rejected=true;}check(rejected);
        rejected=false;try{PresenceRules.slice(bytes,-1);}catch(IllegalArgumentException e){rejected=true;}check(rejected);
        System.out.println("PASS: "+assertions+" Android token/freshness/ATT-boundary assertions");
    }
}
