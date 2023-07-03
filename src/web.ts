import { WebPlugin } from '@capacitor/core';

import type { DeviceBindingPlugin } from './definitions';

export class DeviceBindingWeb extends WebPlugin implements DeviceBindingPlugin {
  async echo(options: { value: string }): Promise<{ value: string }> {
    console.log('ECHO', options);
    return options;
  }
}
