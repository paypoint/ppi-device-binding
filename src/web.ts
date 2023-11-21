import { WebPlugin } from '@capacitor/core';

import type { DeviceBindingPlugin } from './definitions';

export class DeviceBindingWeb extends WebPlugin implements DeviceBindingPlugin {
  async echo(options: { value: string }): Promise<{ value: string }> {
    console.log('ECHO', options);
    return options;
  }

  // checkPermission(): Promise<{ value: string }>;
  async checkPermission(): Promise<{ value: string }> {
    return {value:"WEB"};
  }

  async checkSMSPermisson(): Promise<{ value: string }>{
    return {value:"WEB"}
  }

  async checkSimPresent(): Promise<{ value: boolean }> {
      return {value:false}
  }

  async getSubscriptionIds(): Promise<{ value: string }> {
      return {value:""}
  }

  async sendMessage(options: {
    destinationNumber: string,
    sourceNumber: string,
    messageContent: string,
    subId: number
  }): Promise<{ value: boolean; }> {
    console.log('ECHO', options);  
    return { value: false }
  }

  async setSmartIntent(options: { enable: boolean }): Promise<{ value: boolean }> {
    console.log('ECHO', options);  
    return { value: false }
  }

  async iOSComposeSMS(options: {
    destinationNumber: string,
    messageContent: string
  }): Promise<any>{
    console.log('ECHO', options);  
    return { value: "" }
  }

  async requestWithWrapper(options: { url: string, method: string, parameters: object, headers: object }): Promise<any>{
    console.log("options : ", options);
    return {value:""}
  }

  async echo2(options: { value: string }): Promise<{ value: string }> {
    console.log('ECHO', options);
    return options;
  }
}
