package in.digikhata.devicebinding;

import android.util.Log;

public class DeviceBinding {

    public String echo(String value) {
        Log.i("Echo", value);
        return value;
    }

    public String checkPermission() {

        Log.i("Echo","checkPermission");
        return "TEST";
    }
}
