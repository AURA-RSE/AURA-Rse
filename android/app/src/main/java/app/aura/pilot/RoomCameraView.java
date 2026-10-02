package app.aura.pilot;

import android.content.Context;
import android.widget.FrameLayout;
import androidx.camera.core.CameraSelector;
import androidx.camera.core.Preview;
import androidx.camera.lifecycle.ProcessCameraProvider;
import androidx.camera.view.PreviewView;
import androidx.lifecycle.LifecycleOwner;
import java.util.function.Consumer;

/** Local preview only: no frame analysis, recording, upload or face identification. */
// Constructed with an explicit lifecycle owner; never inflated from XML.
@android.annotation.SuppressLint("ViewConstructor")
final class RoomCameraView extends FrameLayout {
    private final LifecycleOwner owner;
    private final Consumer<String> status;
    private final PreviewView view;
    private ProcessCameraProvider provider;
    private Preview preview;
    private int generation;
    RoomCameraView(Context context,LifecycleOwner owner,Consumer<String> status){
        super(context);this.owner=owner;this.status=status;setTag("room-camera-preview");
        view=new PreviewView(context);view.setImplementationMode(PreviewView.ImplementationMode.COMPATIBLE);view.setScaleType(PreviewView.ScaleType.FILL_CENTER);addView(view,new LayoutParams(-1,-1));
        view.getPreviewStreamState().observe(owner,state->{if(isAttachedToWindow())status.accept(state==PreviewView.StreamState.STREAMING?"Camera live · nothing is recorded":"Starting camera…");});
    }
    @Override protected void onAttachedToWindow(){super.onAttachedToWindow();final int run=++generation;status.accept("Starting camera…");var future=ProcessCameraProvider.getInstance(getContext());future.addListener(()->{
        if(run!=generation||!isAttachedToWindow())return;
        try{provider=future.get();preview=new Preview.Builder().build();preview.setSurfaceProvider(view.getSurfaceProvider());provider.bindToLifecycle(owner,CameraSelector.DEFAULT_BACK_CAMERA,preview);}
        catch(Exception e){status.accept("Camera unavailable. You can still use nearby profiles.");}
    },getContext().getMainExecutor());}
    @Override protected void onDetachedFromWindow(){generation++;if(provider!=null&&preview!=null)provider.unbind(preview);preview=null;view.getPreviewStreamState().removeObservers(owner);super.onDetachedFromWindow();}
}
