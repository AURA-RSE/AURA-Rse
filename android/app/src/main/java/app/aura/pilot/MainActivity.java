package app.aura.pilot;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.Intent;
import android.content.SharedPreferences;
import android.graphics.BitmapFactory;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.media.MediaMetadataRetriever;
import android.net.Uri;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.text.Editable;
import android.text.InputType;
import android.text.TextWatcher;
import android.util.Base64;
import android.view.Gravity;
import android.view.View;
import android.view.WindowInsets;
import android.widget.*;
import org.json.JSONArray;
import org.json.JSONObject;
import java.io.ByteArrayOutputStream;
import java.util.*;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/** Native Android pilot with opt-in BLE and official Mobile Wallet Adapter signing. */
public final class MainActivity extends Activity implements BleDiscovery.Listener {
    private static final int BG = Color.rgb(11,13,18), PANEL = Color.rgb(20,25,34), LIME = Color.rgb(209,255,114), MUTED = Color.rgb(158,169,182);
    private static final String[] INTENTS = {"Building","Hiring","Fundraising","Looking for a team","Offering feedback","Open to connect"};
    private final Handler main = new Handler(Looper.getMainLooper());
    private final ExecutorService io = Executors.newFixedThreadPool(4);
    // Serialize creation, renewal and revocation so a late stop cannot delete a newer presence.
    private final ExecutorService presenceIo = Executors.newSingleThreadExecutor();
    private final Map<String, Peer> peers = new LinkedHashMap<>();
    private final Set<String> resolving = new HashSet<>();
    private final NativeWallet nativeWallet = new NativeWallet();
    private SecureSession sessions;
    private SharedPreferences preferences;
    private AuraApi api;
    private BleDiscovery radio;
    private LinearLayout root, body, nearbyList;
    private TextView notice;
    private JSONObject profile;
    private JSONArray events = new JSONArray(), connections = new JSONArray(), payments = new JSONArray();
    private String origin, token, selectedEvent = "", tab = "Discover", search = "", intent = "All";
    private String pairingSecret, pairingCode;
    private long pairingExpires, presenceExpires;
    private int authEpoch, discoveryEpoch;
    private boolean foreground, destroyed, active, starting, heartbeatBusy;
    private final Runnable pairingPoll = this::pollPairing;
    private final Runnable heartbeat = this::heartbeat;
    private static final class Peer { JSONObject profile; String device; long seen, expires; int rssi; }
    private interface Work { JSONObject run(AuraApi client) throws Exception; }
    private interface Done { void accept(JSONObject result) throws Exception; }

    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        preferences = getSharedPreferences("aura-settings", MODE_PRIVATE); sessions = new SecureSession(this); radio = new BleDiscovery(this,this);
        origin = preferences.getString("server", BuildConfig.DEBUG ? "http://10.0.2.2:4317" : "");
        try { if (!origin.isEmpty()) token = sessions.read(origin); } catch (Exception ignored) { token = null; }
        api = new AuraApi(origin, token); render();
        if (token != null) request(c -> c.get("/api/me"), r -> { profile = r.getJSONObject("profile"); refresh(); }, null);
    }
    @Override protected void onStart() { super.onStart();foreground = true;if(profile!=null)render();if (pairingSecret != null) main.post(pairingPoll); }
    @Override protected void onStop() { foreground = false;main.removeCallbacks(pairingPoll);stopDiscovery();super.onStop(); }
    @Override protected void onDestroy() { destroyed = true;main.removeCallbacksAndMessages(null);radio.stop();nativeWallet.close();presenceIo.shutdown();io.shutdown();super.onDestroy(); }
    private void request(Work work, Done done, Done failed) { requestOn(io, work, done, failed); }
    private void requestPresence(Work work, Done done, Done failed) { requestOn(presenceIo, work, done, failed); }
    private void requestOn(ExecutorService executor, Work work, Done done, Done failed) {
        final int epoch = authEpoch; final AuraApi client = api;
        executor.execute(() -> {
            try {
                JSONObject result = work.run(client);
                main.post(() -> { if (destroyed || epoch != authEpoch) return;try { done.accept(result); } catch (Exception e) { problem(e); } });
            } catch (Exception error) {
                main.post(() -> {
                    if (destroyed || epoch != authEpoch) return;
                    if (error instanceof AuraApi.Failure && ((AuraApi.Failure)error).status == 401 && token != null) { clearSession();message("Session expired. Verify your wallet and pair again.");return; }
                    if (failed != null) { try { failed.accept(AuraApi.object("error", safeMessage(error))); } catch (Exception e) { problem(e); } }
                    else problem(error);
                });
            }
        });
    }
    private String safeMessage(Exception e) { return e.getMessage() == null ? "Request could not complete." : e.getMessage(); }
    private void problem(Exception e) { message(safeMessage(e)); }
    private void message(String text) { if (notice != null) notice.setText(text); }
    private int dp(int value) { return Math.round(value * getResources().getDisplayMetrics().density); }
    private LinearLayout column() { LinearLayout v = new LinearLayout(this);v.setOrientation(LinearLayout.VERTICAL);return v; }
    private GradientDrawable background(int color, int radius) { GradientDrawable d = new GradientDrawable();d.setColor(color);d.setCornerRadius(dp(radius));return d; }
    private TextView text(String value, int size, int color) { TextView t = new TextView(this);t.setText(value);t.setTextSize(size);t.setTextColor(color);t.setPadding(0,dp(6),0,dp(8));return t; }
    private void title(LinearLayout parent, String value) { TextView t = text(value,27,Color.WHITE);t.setTypeface(null,Typeface.BOLD);parent.addView(t); }
    private Button button(LinearLayout parent, String label, Runnable action) {
        Button b = new Button(this);b.setText(label);b.setAllCaps(false);b.setTextColor(LIME);b.setTextSize(14);b.setBackground(background(PANEL,12));
        LinearLayout.LayoutParams p = new LinearLayout.LayoutParams(-1,dp(52));p.setMargins(0,dp(8),0,dp(4));parent.addView(b,p);b.setEnabled(!nativeWallet.busy());b.setOnClickListener(v -> action.run());return b;
    }
    private EditText field(LinearLayout parent,String label,String value,int max) {
        parent.addView(text(label,12,MUTED));EditText edit = new EditText(this);edit.setTextColor(Color.WHITE);edit.setTextSize(15);edit.setSingleLine(true);edit.setText(value);edit.setBackground(background(PANEL,8));edit.setPadding(dp(14),dp(10),dp(14),dp(10));edit.setFilters(new android.text.InputFilter[]{new android.text.InputFilter.LengthFilter(max)});parent.addView(edit,new LinearLayout.LayoutParams(-1,dp(50)));return edit;
    }
    private Spinner select(LinearLayout parent,String label,List<String> labels,int selection,java.util.function.IntConsumer change) {
        parent.addView(text(label,12,MUTED));Spinner spinner = new Spinner(this);ArrayAdapter<String> adapter = new ArrayAdapter<>(this,android.R.layout.simple_spinner_dropdown_item,labels);spinner.setAdapter(adapter);spinner.setSelection(Math.max(0,selection));parent.addView(spinner,new LinearLayout.LayoutParams(-1,dp(48)));
        spinner.setOnItemSelectedListener(new AdapterView.OnItemSelectedListener(){public void onItemSelected(AdapterView<?> p,View view,int i,long id){change.accept(i);}public void onNothingSelected(AdapterView<?> p){}});return spinner;
    }
    private void render() {
        if (destroyed) return;
        root = column();root.setBackgroundColor(BG);
        root.setOnApplyWindowInsetsListener((v,insets)->{var bars=insets.getInsets(WindowInsets.Type.systemBars());v.setPadding(dp(22)+bars.left,bars.top,dp(22)+bars.right,bars.bottom);return insets;});
        TextView logo = text("aura◌",34,Color.WHITE);logo.setTypeface(null,Typeface.BOLD);root.addView(logo);
        notice = text("DEVNET PILOT · Your wallet keys stay in your wallet.",12,MUTED);root.addView(notice);
        ScrollView scroll = new ScrollView(this);body = column();body.setPadding(0,dp(12),0,dp(28));scroll.addView(body);root.addView(scroll,new LinearLayout.LayoutParams(-1,0,1));
        if (profile != null) {
            LinearLayout tabs = new LinearLayout(this);tabs.setGravity(Gravity.CENTER);
            for (String name : new String[]{"Discover","People","Activity","My Aura"}) {
                TextView t = text(name,12,tab.equals(name)?LIME:MUTED);t.setGravity(Gravity.CENTER);t.setPadding(0,dp(19),0,dp(19));tabs.addView(t,new LinearLayout.LayoutParams(0,-2,1));t.setOnClickListener(v->{tab=name;render();if (!"Discover".equals(tab)) refresh();});
            }
            root.addView(tabs);
        }
        if(nativeWallet.busy()){Button cancel=new Button(this);cancel.setText(R.string.close_wallet_request);root.addView(cancel);cancel.setOnClickListener(v->{nativeWallet.cancel();render();message("Wallet request closed. Check Activity before starting another payment.");});}
        setContentView(root);root.requestApplyInsets();
        if (profile == null) onboarding();else switch(tab) {case "People":people();break;case "Activity":activity();break;case "My Aura":profileEditor();break;default:discover();}
    }
    private void onboarding() {
        title(body,"Your people.\nAlready in the room.");body.addView(text("Connect your identity, choose to be seen, and find a reason to say hello.",16,MUTED));
        EditText server = field(body,"Aura server origin",origin,300);server.setInputType(InputType.TYPE_CLASS_TEXT|InputType.TYPE_TEXT_VARIATION_URI);
        body.addView(text("Android emulator: http://10.0.2.2:4317. A physical phone needs your Mac’s LAN address or an HTTPS server. Use that same origin in the browser.",12,MUTED));
        button(body,"Connect Android wallet ↗",()->nativeSignIn(server.getText().toString()));
        body.addView(text("Use an installed MWA-compatible wallet, or pair through the browser below. Devnet only.",12,MUTED));
        button(body,"Create pairing code ↗",()->{
            try {
                String normalized = AuraApi.normalize(server.getText().toString(),BuildConfig.DEBUG);stopDiscovery();authEpoch++;origin=normalized;token=null;api=new AuraApi(origin,null);preferences.edit().putString("server",origin).apply();
                request(c->c.post("/api/device/start",AuraApi.object()),r->{pairingSecret=r.getString("deviceSecret");pairingCode=r.getString("code");pairingExpires=r.getLong("expires");render();if(foreground)main.post(pairingPoll);},null);
            } catch(Exception e){problem(e);}
        });
        if(pairingSecret!=null){TextView code=text(pairingCode,30,LIME);code.setTypeface(Typeface.MONOSPACE);code.setTextIsSelectable(true);body.addView(code);body.addView(text("Verify your wallet in the web companion, then approve this code under Connect your phone. The code expires in five minutes.",14,MUTED));button(body,"Open wallet companion ↗",()->open(origin));}
        body.addView(text("This Android build supports nearby discovery. Precise Android UWB/AR positioning remains in development. Native wallet integration requires a compatible installed wallet.",12,MUTED));
    }
    private void pollPairing() {
        if(!foreground||destroyed||pairingSecret==null)return;
        if(System.currentTimeMillis()>=pairingExpires){pairingSecret=null;render();message("Pairing expired. Generate a fresh code.");return;}
        String secret=pairingSecret;
        request(c->c.post("/api/device/poll",AuraApi.object("deviceSecret",secret)),r->{
            if(!secret.equals(pairingSecret))return;
            if(r.has("token")){String received=r.getString("token");sessions.save(origin,received);token=received;api=new AuraApi(origin,token);profile=r.getJSONObject("profile");pairingSecret=null;main.removeCallbacks(pairingPoll);refresh();}
            else if(foreground)main.postDelayed(pairingPoll,2000);
        },r->{if(!secret.equals(pairingSecret))return;pairingSecret=null;render();message(r.optString("error"));});
    }
    private void refresh() {
        if(token==null)return;
        request(c->AuraApi.object("events",c.get("/api/events").getJSONArray("events"),"connections",c.get("/api/connections").getJSONArray("connections"),"payments",c.get("/api/payments").getJSONArray("payments")),r->{
            events=r.getJSONArray("events");connections=r.getJSONArray("connections");payments=r.getJSONArray("payments");boolean found=false;for(int i=0;i<events.length();i++)if(events.getJSONObject(i).getString("id").equals(selectedEvent))found=true;
            if(!found)selectedEvent=events.length()>0?events.getJSONObject(0).getString("id"):"";render();
        },null);
    }
    private void discover() {
        body.addView(text("THE ROOM IS YOURS.",11,LIME));title(body,"Find your people.");
        List<String> names=new ArrayList<>();List<String> ids=new ArrayList<>();int chosen=0;
        for(int i=0;i<events.length();i++){JSONObject e=events.optJSONObject(i);names.add(e.optString("name"));ids.add(e.optString("id"));if(e.optString("id").equals(selectedEvent))chosen=i;}
        if(names.isEmpty()){names.add("Join an event in My Aura");ids.add("");}
        Spinner event=select(body,"Your event",names,chosen,i->selectedEvent=ids.get(i));event.setEnabled(!active && !starting);
        button(body,active?"Pause discovery":starting?"Cancel discovery start":"Start discovery ↗",()->{if(active||starting){stopDiscovery();render();}else startDiscovery();});
        body.addView(text(active?"Keep Aura open. Nearby participants appear when their devices are discovered.":"Your phone is not broadcasting. Select a visible status and start when you are ready.",13,MUTED));
        EditText query=field(body,"Search name, role or project",search,100);query.addTextChangedListener(new TextWatcher(){public void beforeTextChanged(CharSequence s,int a,int b,int c){}public void onTextChanged(CharSequence s,int a,int b,int c){search=s.toString();renderPeers();}public void afterTextChanged(Editable e){}});
        List<String> filters=new ArrayList<>();filters.add("All");filters.addAll(Arrays.asList(INTENTS));select(body,"Connection intent",filters,filters.indexOf(intent),i->{intent=filters.get(i);renderPeers();});
        nearbyList=column();body.addView(nearbyList);renderPeers();
    }
    private void renderPeers() {
        if(nearbyList==null||!"Discover".equals(tab))return;nearbyList.removeAllViews();int count=0;
        for(Peer peer:peers.values()){
            JSONObject p=peer.profile;String searchable=p.optString("name")+" "+p.optString("role")+" "+p.optString("project");
            if(!searchable.toLowerCase(Locale.ROOT).contains(search.toLowerCase(Locale.ROOT)))continue;
            boolean matches="All".equals(intent);JSONArray intents=p.optJSONArray("intents");if(intents!=null)for(int i=0;i<intents.length();i++)if(intent.equals(intents.optString(i)))matches=true;if(!matches)continue;
            count++;button(nearbyList,p.optString("name")+"\n"+p.optString("role")+" · "+p.optString("project"),()->detail(p,""));nearbyList.addView(text("heads-down".equals(p.optString("status"))?"Heads down · avoid interruptions":"Open to connect",12,MUTED));
        }
        if(count==0)nearbyList.addView(text("No matching participants discovered yet. Nothing is simulated here.",14,MUTED));
    }
    private void startDiscovery() {
        if(active || starting || !foreground || destroyed)return;
        if(profile==null||profile.optString("name").isEmpty()||"stealth".equals(profile.optString("status"))||selectedEvent.isEmpty()){message("Save your profile, choose Open or Heads down, and join an event first.");return;}
        if(!radio.permitted()){requestPermissions(BleDiscovery.PERMISSIONS,10);return;}
        final int run=++discoveryEpoch;final String event=selectedEvent;starting=true;render();
        requestPresence(c->c.post("/api/presence",AuraApi.object("event",event)),r->{
            if(run!=discoveryEpoch||!foreground)return;
            starting=false;presenceExpires=r.getLong("expires");active=true;radio.start(r.getString("token"),presenceExpires);render();if(active)main.postDelayed(heartbeat,1000);
        },r->{if(run!=discoveryEpoch)return;stopDiscovery();render();message(r.optString("error"));});
    }
    @Override public void onRequestPermissionsResult(int requestCode,String[] permissions,int[] grants){super.onRequestPermissionsResult(requestCode,permissions,grants);if(requestCode==10){if(radio.permitted())startDiscovery();else message("Nearby Devices access was denied. You can still use your profile and saved connections.");}}
    private void heartbeat() {
        if(!active||!foreground||destroyed)return;long now=System.currentTimeMillis();peers.values().removeIf(p->!PresenceRules.fresh(p.seen,p.expires,now));renderPeers();
        if(!radio.ready()||presenceExpires<=now){stopDiscovery();render();message("Discovery stopped: Bluetooth or presence is unavailable.");return;}
        if(!heartbeatBusy){heartbeatBusy=true;final int run=discoveryEpoch;final boolean renew=presenceExpires-now<40000;final String event=selectedEvent;
            requestPresence(c->{JSONObject result=c.get("/api/me");if(renew&&!"stealth".equals(result.getJSONObject("profile").getString("status")))result.put("presence",c.post("/api/presence",AuraApi.object("event",event)));return result;},r->{
                if(!active||run!=discoveryEpoch)return;heartbeatBusy=false;profile=r.getJSONObject("profile");if("stealth".equals(profile.optString("status"))){stopDiscovery();render();return;}
                if(r.has("presence")){JSONObject p=r.getJSONObject("presence");presenceExpires=p.getLong("expires");radio.renew(p.getString("token"),presenceExpires);}
            },r->{if(!active||run!=discoveryEpoch)return;heartbeatBusy=false;stopDiscovery();render();message(r.optString("error"));});
        }
        main.postDelayed(heartbeat,3000);
    }
    private void revoke(){AuraApi current=api;if(token!=null&&!presenceIo.isShutdown())presenceIo.execute(()->{try{current.call("DELETE","/api/presence",AuraApi.object());}catch(Exception ignored){}});}
    private void stopDiscovery(){boolean wasActive=active||starting;active=false;starting=false;discoveryEpoch++;heartbeatBusy=false;main.removeCallbacks(heartbeat);radio.stop();peers.clear();resolving.clear();if(wasActive)revoke();}
    @Override public void onToken(String device,String observed,int rssi){
        if(!active||!resolving.add(observed))return;final int run=discoveryEpoch;
        request(c->c.post("/api/discovery/resolve",AuraApi.object("token",observed)),r->{if(!active||run!=discoveryEpoch)return;resolving.remove(observed);if(!selectedEvent.equals(r.getString("event")))return;Peer peer=new Peer();peer.profile=r.getJSONObject("profile");peer.device=device;peer.rssi=rssi;peer.seen=System.currentTimeMillis();peer.expires=r.getLong("expires");peers.values().removeIf(p->device.equals(p.device));peers.put(peer.profile.getString("wallet"),peer);renderPeers();},r->{if(!active||run!=discoveryEpoch)return;resolving.remove(observed);peers.values().removeIf(p->device.equals(p.device));renderPeers();});
    }
    @Override public void onError(String message){stopDiscovery();render();message(message);}
    @Override public void onState(String message){message(message);}
    private void people(){title(body,"Connections");button(body,"Refresh",this::refresh);if(connections.length()==0)body.addView(text("Discover someone and save their profile. Your notes remain private.",15,MUTED));for(int i=0;i<connections.length();i++){JSONObject c=connections.optJSONObject(i),p=c.optJSONObject("profile");if(p!=null){button(body,p.optString("name")+" · "+p.optString("project"),()->detail(p,c.optString("note")));if(!c.optString("note").isEmpty())body.addView(text(c.optString("note"),13,MUTED));}}}
    private void activity(){title(body,"Activity");body.addView(text("DEVNET ONLY · Confirmation is checked by the server against the transaction. Submitted does not mean confirmed.",13,MUTED));button(body,"Refresh receipts",this::refresh);pendingRecovery();if(payments.length()==0)body.addView(text("No payments yet.",15,MUTED));for(int i=0;i<payments.length();i++){JSONObject p=payments.optJSONObject(i);body.addView(text(java.math.BigDecimal.valueOf(p.optLong("lamports"),9).stripTrailingZeros().toPlainString()+" SOL",22,Color.WHITE));TextView wallet=text("To "+p.optString("recipient"),12,MUTED);wallet.setTextIsSelectable(true);body.addView(wallet);String signature=p.isNull("signature")?"":p.optString("signature");if(!signature.isEmpty())button(body,"Confirmed · open explorer ↗",()->open("https://explorer.solana.com/tx/"+signature+"?cluster=devnet"));else{body.addView(text(p.isNull("submitted_signature")?"Awaiting wallet approval":"Submitted · awaiting confirmation",13,LIME));if(!p.isNull("submitted_signature"))button(body,"Check confirmation",()->request(c->c.post("/api/payments/confirm",AuraApi.object("id",p.optString("id"))),r->{refresh();message("confirmed".equals(r.optString("state"))?"Confirmed on devnet.":"Still pending. No new payment sent.");},null));else if(p.optLong("expires")>System.currentTimeMillis())button(body,"Review in Android wallet ↗",()->reviewNativePayment(p));button(body,"Review / check in wallet companion ↗",()->open(origin+"?payment="+p.optString("id")));}}}
    private void profileEditor(){
        title(body,"My Aura");TextView address=text(profile.optString("wallet"),12,LIME);address.setTextIsSelectable(true);body.addView(address);
        Map<String,EditText> fields=new LinkedHashMap<>();for(String key:new String[]{"name","role","project","bio","link","video"})fields.put(key,field(body,key.substring(0,1).toUpperCase(Locale.ROOT)+key.substring(1),profile.optString(key),key.equals("name")?60:key.equals("role")?80:key.equals("project")?100:500));
        List<String> statuses=List.of("stealth","open","heads-down");final String[] chosen={profile.optString("status","stealth")};select(body,"Presence",statuses,statuses.indexOf(chosen[0]),i->chosen[0]=statuses.get(i));
        List<CheckBox> checks=new ArrayList<>();JSONArray existing=profile.optJSONArray("intents");for(String label:INTENTS){CheckBox check=new CheckBox(this);check.setText(label);check.setTextColor(Color.WHITE);if(existing!=null)for(int i=0;i<existing.length();i++)if(label.equals(existing.optString(i)))check.setChecked(true);body.addView(check);checks.add(check);}
        button(body,"Save profile",()->{JSONObject payload=new JSONObject();try{for(var entry:fields.entrySet())payload.put(entry.getKey(),entry.getValue().getText().toString());JSONArray picked=new JSONArray();for(CheckBox c:checks)if(c.isChecked())picked.put(c.getText());payload.put("intents",picked);payload.put("status",chosen[0]);if("stealth".equals(chosen[0]))stopDiscovery();request(c->c.call("PUT","/api/me",payload),r->{profile=r.getJSONObject("profile");render();message("Profile saved.");},null);}catch(Exception e){problem(e);}});
        body.addView(text("Save text changes before uploading media. Avatars: PNG/JPEG up to 2 MB. Intro video: MP4, up to 30 seconds and 20 MB.",12,MUTED));button(body,"Upload avatar",()->chooseMedia(20,"image/*"));button(body,"Upload intro video",()->chooseMedia(21,"video/mp4"));
        EditText code=field(body,"Event code","",40);button(body,"Join event",()->{String value=code.getText().toString();request(c->c.post("/api/events/join",AuraApi.object("code",value)),r->refresh(),null);});
        body.addView(text("Stealth stops discovery. Saved connections retain profile access unless blocked. Notes are private to your account.",12,MUTED));button(body,"Export, delete and manage blocks ↗",()->open(origin));button(body,"Sign out",()->{AuraApi current=api;stopDiscovery();if(!io.isShutdown())io.execute(()->{try{current.post("/api/auth/logout",AuraApi.object());}catch(Exception ignored){}});clearSession();});
    }
    private void detail(JSONObject peer,String savedNote){
        LinearLayout card=column();card.setPadding(dp(20),dp(12),dp(20),dp(16));title(card,peer.optString("name"));card.addView(text(peer.optString("role")+" · "+peer.optString("project"),15,MUTED));card.addView(text(peer.optString("bio"),14,MUTED));TextView address=text(peer.optString("wallet"),12,LIME);address.setTextIsSelectable(true);card.addView(address);
        String link=peer.optString("link");if(link.startsWith("https://"))button(card,"Visit project / social ↗",()->open(link));String video=peer.optString("video");if(video.startsWith("https://"))button(card,"Watch intro link ↗",()->open(video));
        EditText note=field(card,"Private note",savedNote,1000);button(card,"Save connection",()->{String value=note.getText().toString();request(c->c.call("PUT","/api/connections",AuraApi.object("wallet",peer.optString("wallet"),"note",value)),r->{message("Connection saved.");refresh();},null);});
        EditText amount=field(card,"Devnet SOL amount (maximum 1)","0.01",16);amount.setInputType(InputType.TYPE_CLASS_NUMBER|InputType.TYPE_NUMBER_FLAG_DECIMAL);button(card,"Review in Android wallet ↗",()->{String value=amount.getText().toString();request(c->c.post("/api/payments",AuraApi.object("wallet",peer.optString("wallet"),"amount",value)),this::reviewNativePayment,null);});button(card,"Review payment in wallet companion ↗",()->{String value=amount.getText().toString();request(c->c.post("/api/payments",AuraApi.object("wallet",peer.optString("wallet"),"amount",value)),r->open(origin+"?payment="+r.getString("id")),null);});
        card.addView(text("No payment is sent until you review the full recipient and approve in your wallet. Android positioning is not enabled in this build.",12,MUTED));
        EditText report=field(card,"Report a concern","",1000);button(card,"Submit report",()->{String value=report.getText().toString();request(c->c.post("/api/reports",AuraApi.object("wallet",peer.optString("wallet"),"reason",value)),r->{message("Report stored for operator review.");report.setText("");},null);});
        ScrollView scroll=new ScrollView(this);scroll.addView(card);AlertDialog dialog=new AlertDialog.Builder(this).setView(scroll).setNegativeButton("Close",null).create();
        button(card,"Block participant",()->new AlertDialog.Builder(this).setTitle("Block "+peer.optString("name")+"?").setMessage("This prevents profile access between your accounts.").setNegativeButton("Cancel",null).setPositiveButton("Block",(d,w)->request(c->c.post("/api/blocks",AuraApi.object("wallet",peer.optString("wallet"))),r->{peers.remove(peer.optString("wallet"));dialog.dismiss();refresh();},null)).show());
        String avatar=peer.isNull("avatarMediaId")?"":peer.optString("avatarMediaId");if(!avatar.isEmpty()){ImageView image=new ImageView(this);card.addView(image,0,new LinearLayout.LayoutParams(dp(70),dp(70)));request(c->AuraApi.object("data",Base64.encodeToString(c.media(avatar),Base64.NO_WRAP)),r->{byte[] bytes=Base64.decode(r.getString("data"),Base64.NO_WRAP);image.setImageBitmap(BitmapFactory.decodeByteArray(bytes,0,bytes.length));},r->{});}
        if(!peer.isNull("videoMediaId")&&!peer.optString("videoMediaId").isEmpty())button(card,"Play uploaded intro",()->playVideo(peer.optString("videoMediaId")));
        dialog.show();
    }
    private void nativeSignIn(String requestedOrigin) {
        if(nativeWallet.busy())return;
        try {
            String normalized=AuraApi.normalize(requestedOrigin,BuildConfig.DEBUG);
            stopDiscovery();authEpoch++;origin=normalized;token=null;pairingSecret=null;main.removeCallbacks(pairingPoll);
            api=new AuraApi(origin,null);preferences.edit().putString("server",origin).apply();
            final int epoch=authEpoch;final AuraApi client=api;final String server=origin;
            nativeWallet.transact(this,wallet->WalletFlow.signIn(wallet,client,server),(result,error)->{
                if(destroyed||epoch!=authEpoch)return;
                if(error!=null){render();message(walletError(error));return;}
                try{String received=result.getString("token");sessions.save(server,received);token=received;api=new AuraApi(server,token);profile=result.getJSONObject("profile");tab="My Aura";refresh();}
                catch(Exception e){render();problem(e);}
            });
            if(nativeWallet.busy()){render();message("Approve wallet access and the Aura sign-in message. No transaction is requested.");}
        }catch(Exception e){problem(e);}
    }
    private String walletError(Exception error){
        if(error instanceof java.util.concurrent.TimeoutException)return "Wallet request timed out. Check Activity for any signed payment before retrying.";
        if(error instanceof InterruptedException||error instanceof java.util.concurrent.CancellationException)return "Wallet request closed. Check Activity for any signed payment.";
        return safeMessage(error);
    }
    private void reviewNativePayment(JSONObject payment){
        if(nativeWallet.busy()||profile==null)return;
        try{
            String wallet=profile.getString("wallet");
            if(WalletFlow.pending(sessions,origin,wallet)!=null){tab="Activity";render();message("Recover your existing signed payment before signing another.");return;}
            if(!wallet.equals(payment.getString("sender")))throw new IllegalArgumentException("This payment belongs to another wallet.");
            String amount=java.math.BigDecimal.valueOf(payment.getLong("lamports"),9).stripTrailingZeros().toPlainString();
            TextView review=text("DEVNET ONLY\n\n"+amount+" SOL\n\nFrom\n"+wallet+"\n\nTo\n"+payment.getString("recipient")+"\n\nYour wallet will show the network fee and request final approval.",15,Color.WHITE);review.setTextIsSelectable(true);review.setPadding(dp(22),dp(16),dp(22),dp(16));
            new AlertDialog.Builder(this).setTitle("Review payment").setView(review).setNegativeButton("Cancel",null).setPositiveButton("Continue to wallet",(dialog,which)->{
                if(nativeWallet.busy()||profile==null||!wallet.equals(profile.optString("wallet")))return;
                stopDiscovery();final int epoch=authEpoch;final AuraApi client=api;final String server=origin;
                nativeWallet.transact(this,adapter->WalletFlow.pay(adapter,client,sessions,server,wallet,payment),(result,error)->{
                    if(destroyed||epoch!=authEpoch)return;tab="Activity";render();
                    if(error!=null){message(walletError(error)+" Check Activity for a saved signature.");return;}
                    request(c->c.get("/api/payments"),r->{payments=r.getJSONArray("payments");render();message("confirmed".equals(result.optString("state"))?"Confirmed on Solana devnet.":"Signed payment submitted. Use recovery to check confirmation; do not sign again.");},null);
                });
                if(nativeWallet.busy()){render();message("Review and approve this exact payment in your wallet.");}
            }).show();
        }catch(Exception e){problem(e);}
    }
    private void pendingRecovery(){
        try{
            final String server=origin,wallet=profile.getString("wallet");JSONObject saved=WalletFlow.pending(sessions,server,wallet);if(saved==null)return;
            body.addView(text("SIGNED PAYMENT SAVED",12,LIME));TextView signature=text(saved.getString("signature"),12,MUTED);signature.setTextIsSelectable(true);body.addView(signature);
            body.addView(text("Check the existing signature and, if needed, retry the identical signed transaction. This never requests a second signature. An expired or failed transaction may need manual review.",12,MUTED));
            button(body,"Recover signed payment",()->request(c->WalletFlow.recover(c,sessions,server,wallet),r->{refresh();message("confirmed".equals(r.optString("state"))?"Transaction confirmed.":"Confirmation still pending.");},null));
        }catch(Exception e){problem(e);}
    }
    private void playVideo(String id){
        AuraApi current=api;int epoch=authEpoch;io.execute(()->{try{byte[] bytes=current.media(id);java.io.File file=java.io.File.createTempFile("aura-intro-",".mp4",getCacheDir());try(var out=new java.io.FileOutputStream(file)){out.write(bytes);}main.post(()->{if(destroyed||epoch!=authEpoch){file.delete();return;}VideoView video=new VideoView(this);video.setVideoPath(file.getAbsolutePath());MediaController control=new MediaController(this);control.setAnchorView(video);video.setMediaController(control);AlertDialog dialog=new AlertDialog.Builder(this).setView(video).setPositiveButton("Close",null).create();dialog.setOnDismissListener(d->{video.stopPlayback();file.delete();});dialog.show();video.getLayoutParams().height=dp(300);video.requestLayout();});}catch(Exception e){main.post(()->{if(!destroyed)problem(e);});}});
    }
    private void chooseMedia(int request,String type){Intent pick=new Intent(Intent.ACTION_OPEN_DOCUMENT);pick.addCategory(Intent.CATEGORY_OPENABLE);pick.setType(type);startActivityForResult(pick,request);}
    @Override protected void onActivityResult(int request,int result,Intent data){
        super.onActivityResult(request,result,data);if(result!=RESULT_OK||data==null||data.getData()==null||(request!=20&&request!=21))return;Uri uri=data.getData();String kind=request==20?"avatar":"video";int limit=(request==20?2:20)*1024*1024;
        request(c->{ByteArrayOutputStream bytes=new ByteArrayOutputStream();try(var stream=getContentResolver().openInputStream(uri)){if(stream==null)throw new IllegalArgumentException("File unavailable.");byte[] buffer=new byte[8192];int size;while((size=stream.read(buffer))!=-1){if(bytes.size()+size>limit)throw new IllegalArgumentException("File exceeds the upload limit.");bytes.write(buffer,0,size);}}
            if("video".equals(kind)){try(MediaMetadataRetriever metadata=new MediaMetadataRetriever()){metadata.setDataSource(this,uri);String duration=metadata.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION);if(duration==null||Long.parseLong(duration)>30000)throw new IllegalArgumentException("Choose an intro clip of 30 seconds or less.");}}
            return c.post("/api/media",AuraApi.object("kind",kind,"base64",Base64.encodeToString(bytes.toByteArray(),Base64.NO_WRAP)));},r->{profile=r.getJSONObject("profile");render();message("Media saved with your profile.");},null);
    }
    private void clearSession(){stopDiscovery();nativeWallet.cancel();authEpoch++;try{sessions.clear(origin);}catch(Exception ignored){}token=null;profile=null;pairingSecret=null;api=new AuraApi(origin,null);events=new JSONArray();connections=new JSONArray();payments=new JSONArray();selectedEvent="";main.removeCallbacks(pairingPoll);render();}
    private void open(String url){try{Uri uri=Uri.parse(url);if(!"https".equals(uri.getScheme())&&!(BuildConfig.DEBUG&&"http".equals(uri.getScheme())))throw new IllegalArgumentException("Only HTTPS links are allowed in release builds.");startActivity(new Intent(Intent.ACTION_VIEW,uri));}catch(Exception e){problem(e);}}
}
