import { Component, inject, signal } from '@angular/core';
import { PwaInstallService } from '../../services/pwa-install.service';

@Component({
  selector: 'app-android-install-button',
  standalone: true,
  templateUrl: './android-install-button.component.html',
  styleUrl: './android-install-button.component.css'
})
export class AndroidInstallButtonComponent {
  readonly pwaInstall = inject(PwaInstallService);
  readonly installing = signal(false);

  async install(): Promise<void> {
    if (this.installing()) {
      return;
    }

    this.installing.set(true);
    try {
      await this.pwaInstall.promptInstall();
    } finally {
      this.installing.set(false);
    }
  }
}
