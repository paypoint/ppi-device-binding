export interface DeviceBindingPlugin {
  echo(options: { value: string }): Promise<{ value: string }>;
}
