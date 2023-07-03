import { registerPlugin } from '@capacitor/core';

import type { DeviceBindingPlugin } from './definitions';

const DeviceBinding = registerPlugin<DeviceBindingPlugin>('DeviceBinding', {
  web: () => import('./web').then(m => new m.DeviceBindingWeb()),
});

export * from './definitions';
export { DeviceBinding };
