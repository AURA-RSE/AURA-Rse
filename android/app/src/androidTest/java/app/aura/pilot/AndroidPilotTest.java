package app.aura.pilot;

import android.content.Context;
import android.view.View;
import android.view.ViewGroup;
import android.widget.EditText;
import android.widget.TextView;
import androidx.test.core.app.ActivityScenario;
import androidx.test.ext.junit.runners.AndroidJUnit4;
import androidx.test.platform.app.InstrumentationRegistry;
import org.junit.Test;
import org.junit.runner.RunWith;
import static org.junit.Assert.*;

/** Emulator UI and Keystore checks. Fixture API token is provided by an isolated Node test server. */
@RunWith(AndroidJUnit4.class)
public final class AndroidPilotTest {
    private Context context(){return InstrumentationRegistry.getInstrumentation().getTargetContext();}
    private static View text(View view,String wanted){if(view instanceof TextView&&((TextView)view).getText().toString().equals(wanted))return view;if(view instanceof ViewGroup){ViewGroup group=(ViewGroup)view;for(int i=0;i<group.getChildCount();i++){View found=text(group.getChildAt(i),wanted);if(found!=null)return found;}}return null;}
    private static View partial(View view,String wanted){if(view instanceof TextView&&((TextView)view).getText().toString().contains(wanted))return view;if(view instanceof ViewGroup){ViewGroup group=(ViewGroup)view;for(int i=0;i<group.getChildCount();i++){View found=partial(group.getChildAt(i),wanted);if(found!=null)return found;}}return null;}
    private void awaitText(ActivityScenario<MainActivity> scenario,String value) throws Exception {for(int i=0;i<100;i++){boolean[] found={false};scenario.onActivity(a->found[0]=text(a.findViewById(android.R.id.content),value)!=null);if(found[0])return;Thread.sleep(100);}fail("Missing UI text: "+value);}
    @Test public void encryptedSessionIsScopedAndCanBeCleared() throws Exception {
        SecureSession store=new SecureSession(context());String a="https://keystore-fixture-a.invalid",b="https://keystore-fixture-b.invalid";
        try{store.save(a,"synthetic-bearer-for-keystore-test");assertEquals("synthetic-bearer-for-keystore-test",store.read(a));assertNull(store.read(b));String disk=context().getSharedPreferences("aura-sessions",0).getAll().values().toString();assertFalse(disk.contains("synthetic-bearer-for-keystore-test"));store.clear(a);assertNull(store.read(a));}finally{store.clear(a);}
    }
    @Test public void missingWalletShowsFallbackWithoutCrashing(){
        context().getSharedPreferences("aura-settings",0).edit().clear().commit();
        try(ActivityScenario<MainActivity> scenario=ActivityScenario.launch(MainActivity.class)){
            scenario.onActivity(a->{View root=a.findViewById(android.R.id.content);assertNotNull(text(root,"Create pairing code ↗"));text(root,"Connect Android wallet ↗").performClick();assertNotNull(partial(a.findViewById(android.R.id.content),"Install a wallet supporting Solana Mobile Wallet Adapter"));});
        }
    }
    @Test public void restoredSessionEditsProfileThroughRealApi() throws Exception {
        var args=InstrumentationRegistry.getArguments();String origin=args.getString("auraOrigin"),token=args.getString("auraToken");assertNotNull("Run through scripts/test-android-device.mjs",origin);assertNotNull(token);
        AuraApi api=new AuraApi(origin,token);String old=api.get("/api/me").getJSONObject("profile").getString("name");
        SecureSession store=new SecureSession(context());store.save(origin,token);context().getSharedPreferences("aura-settings",0).edit().putString("server",origin).commit();
        try(ActivityScenario<MainActivity> scenario=ActivityScenario.launch(MainActivity.class)){
            awaitText(scenario,"Find your people.");
            scenario.onActivity(a->text(a.findViewById(android.R.id.content),"My Aura").performClick());awaitText(scenario,old);
            // Wait for the tab's asynchronous refresh to finish before editing.
            Thread.sleep(500);
            scenario.onActivity(a->{View root=a.findViewById(android.R.id.content);View name=text(root,old);assertTrue(name instanceof EditText);((EditText)name).setText("Android UI verified");text(root,"Save profile").performClick();});
            awaitText(scenario,"Profile saved.");assertEquals("Android UI verified",api.get("/api/me").getJSONObject("profile").getString("name"));
            scenario.recreate();awaitText(scenario,"Find your people.");assertEquals("Android UI verified",api.get("/api/me").getJSONObject("profile").getString("name"));
        }finally{store.clear(origin);context().getSharedPreferences("aura-settings",0).edit().clear().commit();}
    }
}
