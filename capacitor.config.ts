import { CapacitorConfig } from '@capacitor/cli'

const config: CapacitorConfig = {
  appId: 'com.setbeat.app',
  appName: 'SetBeat',
  webDir: 'dist',
  server: {
    androidScheme: 'https'
  },
  plugins: {
    LocalNotifications: {
      smallIcon: 'ic_stat_icon_configurable',
      iconColor: '#ff6b35'
    }
  }
}

export default config