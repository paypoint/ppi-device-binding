export interface DeviceBindingPlugin {
  echo(options: { value: string }): Promise<{ value: string }>;
  checkPermission(): Promise<{ value: string }>;
  checkSMSPermisson(): Promise<{value: string}>;
  // requestPermission(): Promise<{value: boolean}>;
  checkSimPresent(): Promise<{ value: boolean }>;
  getSubscriptionIds(): Promise<{ value: any }>;
  // selectRegisteredMobileNumber(): Promise<{ value: string }>;
  // selectSimSubscriptionIdToSendMessage(options:{subId:string}): Promise<{ value: string }>;
  sendMessage(options:{destinationNumber:string, sourceNumber: string,  messageContent:string,subId:number}): Promise<{ value: boolean }>;
  // showMessageStatus(): Promise<{ value: string }>;
  setSmartIntent(options: { enable: boolean }): Promise<{ value: boolean }>;
  iOSComposeSMS(options: { destinationNumber: string, messageContent: string }): Promise<any>;
}
