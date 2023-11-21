#import <Foundation/Foundation.h>
#import <Capacitor/Capacitor.h>

// Define the plugin using the CAP_PLUGIN Macro, and
// each method the plugin supports using the CAP_PLUGIN_METHOD macro.
CAP_PLUGIN(DeviceBindingPlugin, "DeviceBinding",
           CAP_PLUGIN_METHOD(echo, CAPPluginReturnPromise);
           CAP_PLUGIN_METHOD(iOSComposeSMS, CAPPluginReturnPromise);
           CAP_PLUGIN_METHOD(echo2,CAPPluginReturnPromise);
           CAP_PLUGIN_METHOD(requestWithWrapper,CAPPluginReturnPromise);
)


