package app.aura.pilot;
import java.nio.file.*;
import java.util.*;
public final class SolanaWireTest {
    private static int assertions;
    private static void check(boolean ok) { assertions++; if(!ok)throw new AssertionError("Check "+assertions+" failed"); }
    private static void rejects(Runnable r) { boolean rejected=false;try{r.run();}catch(IllegalArgumentException e){rejected=true;}check(rejected); }
    public static void main(String[] args) throws Exception {
        Properties fixture=new Properties();try(var reader=Files.newBufferedReader(Path.of(args[0]))){fixture.load(reader);}
        String sender=fixture.getProperty("sender"),recipient=fixture.getProperty("recipient"),reference=fixture.getProperty("reference");long amount=Long.parseLong(fixture.getProperty("lamports"));
        byte[] unsigned=Base64.getDecoder().decode(fixture.getProperty("unsigned")),signed=Base64.getDecoder().decode(fixture.getProperty("signed"));
        SolanaWire.validateUnsigned(unsigned,sender,recipient,amount,reference);check(true);
        check(SolanaWire.verifySignedMessage(unsigned,signed).equals(SolanaWire.base58(Arrays.copyOfRange(signed,1,65))));
        check(SolanaWire.base58(new byte[32]).equals("11111111111111111111111111111111"));
        check(Arrays.equals(SolanaWire.decode58(sender),Arrays.copyOfRange(unsigned,69,101)));
        byte[] leading={0,0,1,2,(byte)255};check(Arrays.equals(leading,SolanaWire.decode58(SolanaWire.base58(leading))));
        rejects(()->SolanaWire.decode58("0OIl"));rejects(()->SolanaWire.decode58(""));
        rejects(()->SolanaWire.validateUnsigned(unsigned,recipient,sender,amount,reference));
        rejects(()->SolanaWire.validateUnsigned(unsigned,sender,recipient,amount+1,reference));
        rejects(()->SolanaWire.validateUnsigned(unsigned,sender,recipient,amount,sender));
        rejects(()->SolanaWire.validateUnsigned(unsigned,sender,recipient,0,reference));
        rejects(()->SolanaWire.validateUnsigned(unsigned,sender,recipient,1_000_000_001L,reference));
        rejects(()->SolanaWire.validateUnsigned(signed,sender,recipient,amount,reference));
        for(int length=0;length<unsigned.length;length++){final byte[] cut=Arrays.copyOf(unsigned,length);rejects(()->SolanaWire.validateUnsigned(cut,sender,recipient,amount,reference));}
        byte[] extra=Arrays.copyOf(unsigned,unsigned.length+1);rejects(()->SolanaWire.validateUnsigned(extra,sender,recipient,amount,reference));
        // Every structural/account/amount byte is independently corrupted; blockhash/signatures are handled separately.
        for(int index=65;index<unsigned.length;index++){if(index>=197&&index<229)continue;byte[] altered=unsigned.clone();altered[index]^=64;rejects(()->SolanaWire.validateUnsigned(altered,sender,recipient,amount,reference));}
        byte[] changed=signed.clone();changed[changed.length-1]^=1;rejects(()->SolanaWire.verifySignedMessage(unsigned,changed));
        rejects(()->SolanaWire.verifySignedMessage(unsigned,unsigned));
        rejects(()->SolanaWire.verifySignedMessage(unsigned,Arrays.copyOf(signed,signed.length-1)));
        System.out.println("PASS: "+assertions+" Solana transaction/codec assertions against a real web3.js fixture (unfunded)");
    }
}
