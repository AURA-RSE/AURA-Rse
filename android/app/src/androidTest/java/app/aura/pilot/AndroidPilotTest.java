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
    private void awaitDialogText(ActivityScenario<MainActivity> scenario,String value) throws Exception {for(int i=0;i<100;i++){boolean[] found={false};scenario.onActivity(a->{for(View window:android.view.inspector.WindowInspector.getGlobalWindowViews())if(text(window,value)!=null)found[0]=true;});if(found[0])return;Thread.sleep(100);}fail("Missing dialog text: "+value);}
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
            awaitText(scenario,"Builders around you.");
            scenario.onActivity(a->text(a.findViewById(android.R.id.content),"My Aura").performClick());awaitText(scenario,old);
            // Wait for the tab's asynchronous refresh to finish before editing.
            Thread.sleep(500);
            scenario.onActivity(a->{View root=a.findViewById(android.R.id.content);View name=text(root,old);assertTrue(name instanceof EditText);((EditText)name).setText("Android UI verified");text(root,"Save profile").performClick();});
            awaitText(scenario,"Profile saved.");assertEquals("Android UI verified",api.get("/api/me").getJSONObject("profile").getString("name"));
            // Event errors stay beside the code without wiping the profile form.
            scenario.onActivity(a->{View root=a.findViewById(android.R.id.content);text(root,"Join event").performClick();assertNotNull(text(root,"Enter an event code first."));((EditText)root.findViewWithTag("event-code")).setText("AURA-LAB");((EditText)text(root,"Android UI verified")).setText("Unsaved edit");text(root,"Join event").performClick();assertNotNull(text(root,"Save your profile changes before joining."));assertNotNull(text(root,"Unsaved edit"));((EditText)text(root,"Unsaved edit")).setText("Android UI verified");((EditText)root.findViewWithTag("event-code")).setText("MISSING-EVENT");text(root,"Join event").performClick();});
            awaitText(scenario,"Could not join: Event code not found");
            api.post("/api/events/leave",AuraApi.object("event","aura-lab"));
            scenario.onActivity(a->{View root=a.findViewById(android.R.id.content);((EditText)root.findViewWithTag("event-code")).setText("AURA-LAB");text(root,"Join event").performClick();});
            awaitText(scenario,"Joined Aura Local Lab. You can start discovery when ready.");
            scenario.onActivity(a->{View root=a.findViewById(android.R.id.content);assertNotNull(text(root,"Builders around you."));assertEquals("Aura Local Lab",((android.widget.Spinner)root.findViewWithTag("Your event")).getSelectedItem().toString());});
            assertEquals(1,api.get("/api/events").getJSONArray("events").length());
            scenario.recreate();awaitText(scenario,"Builders around you.");assertEquals("Android UI verified",api.get("/api/me").getJSONObject("profile").getString("name"));
        }finally{store.clear(origin);context().getSharedPreferences("aura-settings",0).edit().clear().commit();}
    }
    private static void setPrivate(Object object,String name,Object value){try{var f=object.getClass().getDeclaredField(name);f.setAccessible(true);f.set(object,value);}catch(Exception e){throw new AssertionError(e);}}
    private static void callPrivate(Object object,String name){try{var m=object.getClass().getDeclaredMethod(name);m.setAccessible(true);m.invoke(object);}catch(Exception e){throw new AssertionError(e);}}
    @Test public void floatingProfilesFilterOpenAndClearUsingAuthorizedApiFixtures() throws Exception {
        var args=InstrumentationRegistry.getArguments();String origin=args.getString("auraOrigin"),token=args.getString("auraToken"),peerToken=args.getString("auraPeerToken"),otherToken=args.getString("auraOtherPeerToken"),peerWallet=args.getString("auraPeerWallet");
        assertNotNull(peerToken);assertNotNull(otherToken);assertNotNull(peerWallet);
        SecureSession store=new SecureSession(context());store.save(origin,token);context().getSharedPreferences("aura-settings",0).edit().putString("server",origin).commit();
        try(ActivityScenario<MainActivity> scenario=ActivityScenario.launch(MainActivity.class)){
            awaitText(scenario,"Builders around you.");Thread.sleep(500);
            scenario.onActivity(a->{
                // Only the instrumentation test injects observed BLE tokens. The real API
                // still checks membership and consent; no fixture hook ships in the app.
                setPrivate(a,"active",true);callPrivate(a,"render");
                a.onToken("fixture-builder",peerToken,-50);a.onToken("fixture-hiring",otherToken,-55);
            });
            awaitText(scenario,"LIVE IN YOUR EVENT · 2 nearby");
            scenario.onActivity(a->{View root=a.findViewById(android.R.id.content);assertNotNull(root.findViewWithTag("nearby-profile-"+peerWallet));((android.widget.Spinner)root.findViewWithTag("Connection intent")).setSelection(2);});
            awaitText(scenario,"LIVE IN YOUR EVENT · 1 nearby");
            scenario.onActivity(a->{View root=a.findViewById(android.R.id.content);assertNotNull(text(root,"Hiring fixture"));assertNull(text(root,"Builder fixture"));((android.widget.Spinner)root.findViewWithTag("Connection intent")).setSelection(0);});
            awaitText(scenario,"LIVE IN YOUR EVENT · 2 nearby");
            scenario.onActivity(a->((EditText)a.findViewById(android.R.id.content).findViewWithTag("nearby-search")).setText("no-such-project"));
            awaitText(scenario,"Try another filter");
            scenario.onActivity(a->((EditText)a.findViewById(android.R.id.content).findViewWithTag("nearby-search")).setText(""));
            awaitText(scenario,"LIVE IN YOUR EVENT · 2 nearby");
            scenario.onActivity(a->{View root=a.findViewById(android.R.id.content);root.findViewWithTag("nearby-mode-List").performClick();assertNull(root.findViewWithTag("nearby-profile-"+peerWallet));assertNotNull(partial(root,"Builder fixture"));root.findViewWithTag("nearby-mode-Floating").performClick();root.findViewWithTag("nearby-profile-"+peerWallet).performClick();});
            InstrumentationRegistry.getInstrumentation().waitForIdleSync();
            scenario.onActivity(a->{boolean found=false;for(View window:android.view.inspector.WindowInspector.getGlobalWindowViews())if(text(window,"Save connection")!=null){found=true;((EditText)window.findViewWithTag("connection-note")).setText("Met at the test event");text(window,"Save connection").performClick();}assertTrue("Card opens the existing profile detail",found);});
            awaitDialogText(scenario,"Connection and private note saved. Find them in People.");awaitDialogText(scenario,"Saved ✓");
            AuraApi api=new AuraApi(origin,token);var savedConnections=api.get("/api/connections").getJSONArray("connections");assertEquals(1,savedConnections.length());assertEquals("Met at the test event",savedConnections.getJSONObject(0).getString("note"));
            // A rejected update must show its error in the open panel and retain the draft.
            api.post("/api/blocks",AuraApi.object("wallet",peerWallet));
            scenario.onActivity(a->{for(View window:android.view.inspector.WindowInspector.getGlobalWindowViews())if(window.findViewWithTag("connection-note")!=null){((EditText)window.findViewWithTag("connection-note")).setText("Keep this unsaved note");text(window,"Save connection").performClick();}});
            awaitDialogText(scenario,"Could not save: Discover this participant first");awaitDialogText(scenario,"Keep this unsaved note");
            InstrumentationRegistry.getInstrumentation().sendKeyDownUpSync(android.view.KeyEvent.KEYCODE_BACK);
            // Screenshot is explicitly labelled as synthetic UI evidence, not a radio test.
            scenario.onActivity(a->{try{var f=MainActivity.class.getDeclaredField("notice");f.setAccessible(true);((TextView)f.get(a)).setText("TEST FIXTURES · No live people or radio evidence");View root=a.findViewById(android.R.id.content);root.findViewWithTag("nearby-profile-"+peerWallet).requestRectangleOnScreen(new android.graphics.Rect(0,0,1,600),true);}catch(Exception e){throw new AssertionError(e);}});
            InstrumentationRegistry.getInstrumentation().waitForIdleSync();Thread.sleep(350);
            android.graphics.Bitmap screenshot=InstrumentationRegistry.getInstrumentation().getUiAutomation().takeScreenshot();assertNotNull(screenshot);
            java.io.File destination=new java.io.File(context().getExternalFilesDir(null),"nearby-test-fixtures.png");try(var stream=new java.io.FileOutputStream(destination)){screenshot.compress(android.graphics.Bitmap.CompressFormat.PNG,100,stream);}screenshot.recycle();
            // The peer was already blocked for the rejected-save check above.
            scenario.onActivity(a->a.onToken("fixture-builder",peerToken,-50));
            awaitText(scenario,"LIVE IN YOUR EVENT · 1 nearby");
            scenario.onActivity(a->{View root=a.findViewById(android.R.id.content);assertNull(root.findViewWithTag("nearby-profile-"+peerWallet));try{var field=MainActivity.class.getDeclaredField("peers");field.setAccessible(true);for(Object peer:((java.util.Map<?,?>)field.get(a)).values())setPrivate(peer,"expires",System.currentTimeMillis()-1);}catch(Exception e){throw new AssertionError(e);}callPrivate(a,"renderPeers");assertNotNull(text(root,"LIVE IN YOUR EVENT · 0 nearby"));});
            scenario.onActivity(a->{callPrivate(a,"stopDiscovery");View root=a.findViewById(android.R.id.content);assertNotNull(text(root,"Choose when to be seen"));assertNull(root.findViewWithTag("nearby-profile-"+peerWallet));});
        }finally{store.clear(origin);context().getSharedPreferences("aura-settings",0).edit().clear().commit();}
    }

}
