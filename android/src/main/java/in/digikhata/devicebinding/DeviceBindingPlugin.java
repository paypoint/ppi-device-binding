package in.digikhata.devicebinding;

import android.Manifest;
import android.annotation.SuppressLint;
import android.app.Activity;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.telephony.SmsManager;
import android.telephony.SubscriptionInfo;
import android.telephony.SubscriptionManager;
import android.telephony.TelephonyManager;
import android.util.Log;
import android.widget.Toast;

import androidx.core.content.ContextCompat;

import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;
import com.getcapacitor.annotation.Permission;
import com.getcapacitor.PermissionState;
import com.getcapacitor.annotation.PermissionCallback;
//import com.paypointz.wallet.*;

import java.util.List;

@CapacitorPlugin(name = "DeviceBinding", permissions = {
        @Permission(alias = "phone_state", strings = { Manifest.permission.READ_PHONE_STATE }),
        @Permission(alias = "send_sms", strings = { Manifest.permission.SEND_SMS })
})

public class DeviceBindingPlugin extends Plugin {

    private DeviceBinding implementation = new DeviceBinding();
    private static final int CREDENTIAL_PICKER_REQUEST = 120;
    public String selectedPhoneNumber = null;

    @PluginMethod
    public void echo(PluginCall call) {
        String value = call.getString("value");
        JSObject ret = new JSObject();
        ret.put("value", implementation.echo(value));
        call.resolve(ret);
    }

    @PluginMethod
    public void checkPermission(PluginCall call) {
        JSObject ret = new JSObject();
        if (getPermissionState("phone_state") != PermissionState.GRANTED) {
            requestPermissionForAlias("phone_state", call, "phoneStatePermsCallback"); // Get Phone State
        } else {
            Log.d("Echo : ", "Permission Granted");
            ret.put("value", true);
            call.resolve(ret);
        }
    }

    @PluginMethod
    public void checkSMSPermisson(PluginCall call) {
        JSObject ret = new JSObject();
        if (getPermissionState("send_sms") != PermissionState.GRANTED) {
            requestPermissionForAlias("send_sms", call, "smsPermsCallback"); // Send SMS Permission
        } else {
            Log.d("Echo : ", "Permission Granted");
            ret.put("value", true);
            call.resolve(ret);
        }
    }

    @PermissionCallback
    private void phoneStatePermsCallback(PluginCall call) {
        JSObject ret = new JSObject();
        if (getPermissionState("phone_state") == PermissionState.GRANTED
                && getPermissionState("send_sms") == PermissionState.GRANTED) {
            ret.put("value", true);
            call.resolve(ret);
        } else {
            ret.put("value", false);
            call.reject("Permission is required");
        }
    }

    @PermissionCallback
    private void smsPermsCallback(PluginCall call) {
        JSObject ret = new JSObject();
        if (getPermissionState("send_sms") == PermissionState.GRANTED) {
            ret.put("value", true);
            call.resolve(ret);
        } else {
            ret.put("value", false);
            call.reject("Permission is required");
        }
    }

    @PluginMethod
    public void checkSimPresent(PluginCall call) {
        JSObject ret = new JSObject();
        Context context = getContext();
        TelephonyManager telephonyManager = (TelephonyManager) context.getSystemService(Context.TELEPHONY_SERVICE);

        // Check if a SIM card is present
        boolean isSimCardPresent = telephonyManager.getSimState() != TelephonyManager.SIM_STATE_ABSENT;

        if (isSimCardPresent) {
            Log.d("ECHO", "SIM PRESENT");
            ret.put("value", true);
            call.resolve(ret);
        } else {
            Log.d("ECHO", "SIM NOT PRESENT");
            ret.put("value", false);
            call.resolve(ret);
        }
    }

    @PluginMethod
    public void getSubscriptionIds(PluginCall call) {
        JSObject carrier = new JSObject();
        JSObject subIds = new JSObject();
        JSObject nestedRet = new JSObject();
        JSObject ret = new JSObject();
        Context context = getContext();

        if (hasReadPhoneStatePermission(context)) {
            SubscriptionManager subscriptionManager = null;
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.LOLLIPOP_MR1) {
                subscriptionManager = (SubscriptionManager) context
                        .getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE);
                @SuppressLint("MissingPermission")
                List<SubscriptionInfo> subscriptionInfos = subscriptionManager.getActiveSubscriptionInfoList();

                String value = "";
                for (SubscriptionInfo subscriptionInfo : subscriptionInfos) {
                    String carrierName = (String) subscriptionInfo.getCarrierName();
                    Integer number = subscriptionInfo.getSubscriptionId();
                    carrier.put(String.valueOf(number), carrierName);
                    value += number + "";
                }

                nestedRet.put("subids", value);
                nestedRet.put("carrier", carrier);

                ret.put("value", nestedRet);
                call.resolve(ret);
            } else {
                // android version issue
                call.reject("ANDROID_VERSION_NOT_SUPPORTED");
            }
        } else {
            // Permission issue
            call.reject("PHONE_STATE_PERMISSION_ISSUE");
        }
    }

    @PluginMethod
    public void sendMessage(PluginCall call) {
        Activity activity = getActivity();
        String messageContent = call.getString("messageContent");

        String destinationNumber = call.getString("destinationNumber");
        String sourceNumber = call.getString("sourceNumber");
        Integer subId = call.getInt("subId");

        Log.d("SOURCE Number ", sourceNumber);
        Log.d("SIM SUB ID ", subId.toString());

        PendingIntent sentIntent = PendingIntent.getBroadcast(activity, 0, new Intent("SMS_SENT"),
                PendingIntent.FLAG_IMMUTABLE);
        getContext().registerReceiver(smsSentReceiver, new IntentFilter("SMS_SENT"));

        SmsManager smsManager = SmsManager.getSmsManagerForSubscriptionId(subId);

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            try {
                smsManager.sendTextMessage(destinationNumber, null, messageContent, sentIntent, null, subId);
                call.resolve();
            } catch (Exception e) {
                call.reject("Message sending failed : " + e.toString());
            }
        }
    }

    private BroadcastReceiver smsSentReceiver = new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, Intent intent) {
            if (getResultCode() == Activity.RESULT_OK) {
                // SMS sent successfully
                showToast("SMS sent successfully");
            } else {
                // SMS sending failed
                showToast("SMS sending failed");
            }
            context.unregisterReceiver(this);
        }
    };

    private void showToast(String message) {
        Toast.makeText(getActivity(), message, Toast.LENGTH_SHORT).show();
    }

    private boolean hasReadPhoneStatePermission(Context context) {
        boolean hasReadPhoneState = ContextCompat.checkSelfPermission(context,
                android.Manifest.permission.READ_PHONE_STATE) == PackageManager.PERMISSION_GRANTED;
        boolean hasSendSMSPermission = ContextCompat.checkSelfPermission(context,
                android.Manifest.permission.SEND_SMS) == PackageManager.PERMISSION_GRANTED;
        return hasReadPhoneState && hasSendSMSPermission;
    }

    @PluginMethod
    public void setSmartIntent(PluginCall call) {

        Log.d("ECHO", "Smart Intent Started");

        Boolean enable = call.getBoolean("enable");
        JSObject ret = new JSObject();

        ComponentName component = new ComponentName("com.paypointz.wallet", "com.paypointz.wallet.UPI");
        final PackageManager pm = this.getActivity().getPackageManager();

        // ComponentName component = new ComponentName("com.paypointz.wallet",
        // "com.paypointz.wallet.IntentActivity");
        // final PackageManager pm = this.getActivity().getPackageManager();
        //
        //
        if (enable == Boolean.TRUE) {
            Log.d("ECHO", "setSmartIntent Called enabled");
            try {
                enableSmartIntent(component, pm);
            } catch (Exception error) {
                Log.d("ECHO-ERROR", error.toString());
            }

        } else {
            Log.d("ECHO", "setSmartIntent Called disabled");
            try {
                disableSmartIntent(component, pm);
            } catch (Exception error) {
                Log.d("ECHO-ERROR", error.toString());
            }
        }
        //
        // Integer componentResult = pm.getComponentEnabledSetting(component);
        //
        // Log.d("ECHO--", componentResult.toString());

        ret.put("value", true);
        call.resolve(ret);
    }

    private void enableSmartIntent(ComponentName component, PackageManager pm) {
        Log.d("ECHO", "Enable Triggered");
        pm.setComponentEnabledSetting(
                component,
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                PackageManager.DONT_KILL_APP);
    }

    private void disableSmartIntent(ComponentName component, PackageManager pm) {
        Log.d("ECHO", "Disabled Triggered");
        pm.setComponentEnabledSetting(
                component,
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP);
    }
}
