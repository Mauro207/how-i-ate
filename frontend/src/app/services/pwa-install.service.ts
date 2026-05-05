import { DestroyRef, Injectable, computed, inject, signal } from '@angular/core';

type InstallOutcome = 'accepted' | 'dismissed' | 'unavailable';

interface BeforeInstallPromptEvent extends Event {
  prompt: () => Promise<void>;
  userChoice: Promise<{ outcome: 'accepted' | 'dismissed'; platform: string }>;
}

const IOS_HINT_DISMISSED_KEY = 'pwa-ios-install-hint-dismissed';

@Injectable({ providedIn: 'root' })
export class PwaInstallService {
  private readonly destroyRef = inject(DestroyRef);

  private deferredPrompt = signal<BeforeInstallPromptEvent | null>(null);
  private iosHintDismissed = signal(false);
  private iosSafari = signal(false);
  private standaloneMode = signal(false);

  canInstall = computed(() => this.deferredPrompt() !== null);
  showIosHint = computed(() => this.iosSafari() && !this.standaloneMode() && !this.iosHintDismissed());

  constructor() {
    if (typeof window === 'undefined') {
      return;
    }

    this.restoreIosHintDismissal();
    this.iosSafari.set(this.detectIosSafari());
    this.standaloneMode.set(this.detectStandaloneMode());

    window.addEventListener('beforeinstallprompt', this.onBeforeInstallPrompt as EventListener);
    window.addEventListener('appinstalled', this.onAppInstalled);

    this.destroyRef.onDestroy(() => {
      window.removeEventListener('beforeinstallprompt', this.onBeforeInstallPrompt as EventListener);
      window.removeEventListener('appinstalled', this.onAppInstalled);
    });
  }

  async promptInstall(): Promise<InstallOutcome> {
    const promptEvent = this.deferredPrompt();
    if (!promptEvent) {
      return 'unavailable';
    }

    await promptEvent.prompt();
    const result = await promptEvent.userChoice;

    if (result.outcome === 'accepted') {
      this.deferredPrompt.set(null);
    }

    return result.outcome;
  }

  dismissIosHint(): void {
    this.iosHintDismissed.set(true);

    if (typeof window !== 'undefined') {
      window.localStorage.setItem(IOS_HINT_DISMISSED_KEY, '1');
    }
  }

  private onBeforeInstallPrompt = (event: Event): void => {
    event.preventDefault();
    this.deferredPrompt.set(event as BeforeInstallPromptEvent);
  };

  private onAppInstalled = (): void => {
    this.deferredPrompt.set(null);
  };

  private restoreIosHintDismissal(): void {
    const stored = window.localStorage.getItem(IOS_HINT_DISMISSED_KEY);
    this.iosHintDismissed.set(stored === '1');
  }

  private detectStandaloneMode(): boolean {
    return window.matchMedia('(display-mode: standalone)').matches || (window.navigator as Navigator & { standalone?: boolean }).standalone === true;
  }

  private detectIosSafari(): boolean {
    const userAgent = window.navigator.userAgent;
    const platform = window.navigator.platform;
    const touchPoints = window.navigator.maxTouchPoints ?? 0;

    const isIosDevice = /iPad|iPhone|iPod/.test(userAgent) || (platform === 'MacIntel' && touchPoints > 1);
    const isWebkit = /WebKit/i.test(userAgent);
    const isOtherBrowser = /CriOS|FxiOS|EdgiOS|OPiOS/i.test(userAgent);

    return isIosDevice && isWebkit && !isOtherBrowser;
  }
}
