import { Injectable, signal, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { environment } from '../../environments/environment';

@Injectable({
  providedIn: 'root'
})
export class NotificationService {
  private apiUrl = `${environment.apiUrl}/notifications`;
  private http = inject(HttpClient);

  /** true = l'utente ha attivato le notifiche su questo browser */
  notificationsEnabled = signal(false);

  private readonly SW_PATH = '/sw.js';
  private readonly LOCAL_KEY = 'notifications_enabled';

  constructor() {
    this.notificationsEnabled.set(localStorage.getItem(this.LOCAL_KEY) === 'true');
  }

  /** true se il browser mostra la sezione notifiche (anche su Safari) */
  get isUIVisible(): boolean {
    return 'Notification' in window;
  }

  /** true = il browser supporta completamente le Push API */
  get isSupported(): boolean {
    return 'serviceWorker' in navigator && 'PushManager' in window && 'Notification' in window;
  }

  get permissionState(): NotificationPermission {
    return Notification.permission;
  }

  /** Attiva le notifiche: richiede permesso, registra SW e salva la subscription sul backend */
  async enable(): Promise<void> {
    if (!this.isSupported) throw new Error('Le notifiche non sono supportate in questo browser.');

    const permission = await Notification.requestPermission();
    if (permission !== 'granted') throw new Error('Permesso notifiche negato.');

    const registration = await this.getServiceWorkerRegistration();

    const publicKey = await this.getVapidPublicKey();
    const applicationServerKey = this.urlBase64ToUint8Array(publicKey);
    let subscription = await registration.pushManager.getSubscription();

    if (!subscription) {
      subscription = await registration.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey
      });
    }

    await this.http.post(`${this.apiUrl}/subscribe`, {
      subscription: subscription.toJSON(),
      client: this.getClientInfo()
    }).toPromise();

    localStorage.setItem(this.LOCAL_KEY, 'true');
    this.notificationsEnabled.set(true);
  }

  /** Disattiva le notifiche: rimuove la subscription dal browser e dal backend */
  async disable(): Promise<void> {
    const registration = await navigator.serviceWorker.getRegistration(this.SW_PATH);
    if (registration) {
      const subscription = await registration.pushManager.getSubscription();
      if (subscription) {
        await this.http
          .delete(`${this.apiUrl}/unsubscribe`, { body: { endpoint: subscription.endpoint } })
          .toPromise();
        await subscription.unsubscribe();
      }
    }

    localStorage.setItem(this.LOCAL_KEY, 'false');
    this.notificationsEnabled.set(false);
  }

  /** Sincronizza lo stato (utile all'avvio o dopo login) */
  async syncStatus(): Promise<void> {
    if (!this.isSupported) return;

    const registration = await navigator.serviceWorker.getRegistration(this.SW_PATH);
    if (!registration) {
      this.notificationsEnabled.set(false);
      localStorage.setItem(this.LOCAL_KEY, 'false');
      return;
    }

    const subscription = await registration.pushManager.getSubscription();
    const active = !!subscription && Notification.permission === 'granted';
    this.notificationsEnabled.set(active);
    localStorage.setItem(this.LOCAL_KEY, String(active));

    if (active) {
      await this.http.post(`${this.apiUrl}/subscribe`, {
        subscription: subscription.toJSON(),
        client: this.getClientInfo()
      }).toPromise().catch(() => undefined);
    }
  }

  /** Invia una notifica di prova solo all'utente corrente */
  sendTestNotification(): Promise<void> {
    return this.http.post<void>(`${this.apiUrl}/test`, {}).toPromise().then(() => undefined);
  }

  private async getVapidPublicKey(): Promise<string> {
    const res = await this.http.get<{ publicKey: string }>(`${this.apiUrl}/vapid-public-key`).toPromise();
    if (!res?.publicKey) throw new Error('Chiave VAPID non disponibile.');
    return res.publicKey;
  }

  private async getServiceWorkerRegistration(): Promise<ServiceWorkerRegistration> {
    const existingRegistration = await navigator.serviceWorker.getRegistration(this.SW_PATH);
    const registration = existingRegistration || await navigator.serviceWorker.register(this.SW_PATH, { scope: '/' });
    return navigator.serviceWorker.ready.then(() => registration);
  }

  private getClientInfo(): { browser: string; platform: string; standalone: boolean } {
    const ua = navigator.userAgent;
    const standalone = window.matchMedia('(display-mode: standalone)').matches ||
      (navigator as Navigator & { standalone?: boolean }).standalone === true;

    let browser = 'unknown';
    if (/CriOS|Chrome|Chromium/i.test(ua) && !/Edg|OPR/i.test(ua)) browser = 'chrome';
    else if (/Safari/i.test(ua) && !/Chrome|Chromium|CriOS|Edg|OPR|FxiOS|Firefox/i.test(ua)) browser = 'safari';
    else if (/Firefox|FxiOS/i.test(ua)) browser = 'firefox';
    else if (/Edg/i.test(ua)) browser = 'edge';

    return {
      browser,
      platform: navigator.platform || 'unknown',
      standalone
    };
  }

  /** Converte la chiave VAPID (base64url) in Uint8Array richiesto dalla Push API */
  private urlBase64ToUint8Array(base64String: string): ArrayBuffer {
    const padding = '='.repeat((4 - (base64String.length % 4)) % 4);
    const base64 = (base64String + padding).replace(/-/g, '+').replace(/_/g, '/');
    const rawData = atob(base64);
    const outputArray = new Uint8Array(rawData.length);
    for (let i = 0; i < rawData.length; i++) {
      outputArray[i] = rawData.charCodeAt(i);
    }
    return outputArray.buffer.slice(
      outputArray.byteOffset,
      outputArray.byteOffset + outputArray.byteLength
    ) as ArrayBuffer;
  }
}
