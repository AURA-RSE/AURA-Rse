package app.aura.pilot;

import android.animation.ValueAnimator;
import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.view.Gravity;
import android.view.View;
import android.view.accessibility.AccessibilityNodeInfo;
import android.widget.*;
import org.json.JSONArray;
import org.json.JSONObject;

/** A floating browse card. Its screen position carries no physical-location meaning. */
// Constructed in code with an authorized profile; never inflated from XML.
@android.annotation.SuppressLint("ViewConstructor")
public final class NearbyProfileCard extends LinearLayout {
    private static final int LIME=Color.rgb(209,255,114),MUTED=Color.rgb(158,169,182);
    private final FrameLayout avatar;
    private final boolean alternate;
    private ValueAnimator motion;
    public NearbyProfileCard(Context context,JSONObject profile,boolean alternate,Runnable select){
        super(context);this.alternate=alternate;setOrientation(VERTICAL);setPadding(dp(16),dp(18),dp(16),dp(16));
        GradientDrawable surface=new GradientDrawable(GradientDrawable.Orientation.TL_BR,new int[]{alternate?Color.rgb(30,41,30):Color.rgb(22,29,28),Color.rgb(17,21,28)});surface.setCornerRadius(dp(26));surface.setStroke(dp(1),Color.rgb(57,71,47));setBackground(surface);setElevation(dp(5));
        setTag("nearby-profile-"+profile.optString("wallet"));setClickable(true);setFocusable(true);setOnClickListener(v->select.run());
        String name=profile.optString("name"),status="heads-down".equals(profile.optString("status"))?"Heads down":"Open to connect";
        setContentDescription(name+". "+profile.optString("role")+". "+profile.optString("project")+". "+status+". Open nearby profile");
        setAccessibilityDelegate(new View.AccessibilityDelegate(){@Override public void onInitializeAccessibilityNodeInfo(View host,AccessibilityNodeInfo info){super.onInitializeAccessibilityNodeInfo(host,info);info.setClassName(Button.class.getName());}});
        LinearLayout top=new LinearLayout(context);top.setGravity(Gravity.CENTER_VERTICAL);top.setImportantForAccessibility(IMPORTANT_FOR_ACCESSIBILITY_NO_HIDE_DESCENDANTS);
        avatar=new FrameLayout(context);GradientDrawable circle=new GradientDrawable();circle.setColor(Color.rgb(44,57,35));circle.setShape(GradientDrawable.OVAL);avatar.setBackground(circle);avatar.setClipToOutline(true);
        TextView initial=label(name.isEmpty()?"?":name.substring(0,name.offsetByCodePoints(0,1)).toUpperCase(java.util.Locale.ROOT),24,LIME);initial.setGravity(Gravity.CENTER);initial.setTypeface(null,Typeface.BOLD);avatar.addView(initial,new FrameLayout.LayoutParams(-1,-1));top.addView(avatar,new LinearLayout.LayoutParams(dp(52),dp(52)));TextView arrow=label("↗",18,MUTED);arrow.setGravity(Gravity.END);top.addView(arrow,new LinearLayout.LayoutParams(0,-2,1));addView(top);
        TextView title=label(name,17,Color.WHITE);title.setTypeface(null,Typeface.BOLD);title.setPadding(0,dp(14),0,dp(6));addView(title);
        if(!profile.optString("role").isEmpty())addView(label(profile.optString("role"),12,MUTED));
        if(!profile.optString("project").isEmpty()){TextView project=label(profile.optString("project"),14,LIME);project.setPadding(0,dp(6),0,dp(6));addView(project);}
        JSONArray intents=profile.optJSONArray("intents");if(intents!=null&&intents.length()>0){TextView intent=label(intents.optString(0),11,Color.WHITE);intent.setPadding(0,dp(8),0,dp(8));addView(intent);}
        TextView presence=label(("Heads down".equals(status)?"◐ ":"● ")+status,11,"Heads down".equals(status)?Color.rgb(244,185,103):LIME);presence.setPadding(0,dp(8),0,0);addView(presence);
    }
    private int dp(int value){return Math.round(value*getResources().getDisplayMetrics().density);}
    private TextView label(String value,int size,int color){TextView text=new TextView(getContext());text.setText(value);text.setTextSize(size);text.setTextColor(color);text.setImportantForAccessibility(IMPORTANT_FOR_ACCESSIBILITY_NO);return text;}
    public void setAvatar(Bitmap bitmap){if(bitmap==null)return;avatar.removeAllViews();ImageView image=new ImageView(getContext());image.setImageBitmap(bitmap);image.setScaleType(ImageView.ScaleType.CENTER_CROP);avatar.addView(image,new FrameLayout.LayoutParams(-1,-1));}
    @Override protected void onAttachedToWindow(){super.onAttachedToWindow();if(ValueAnimator.areAnimatorsEnabled()){motion=ValueAnimator.ofFloat(-dp(3),dp(3));motion.setDuration(alternate?3600:3000);motion.setRepeatCount(ValueAnimator.INFINITE);motion.setRepeatMode(ValueAnimator.REVERSE);motion.addUpdateListener(a->setTranslationY((float)a.getAnimatedValue()));motion.start();}}
    @Override protected void onDetachedFromWindow(){if(motion!=null){motion.cancel();motion=null;}setTranslationY(0);super.onDetachedFromWindow();}
}
