import { Component, inject } from '@angular/core';
import { PwaInstallService } from '../../services/pwa-install.service';

@Component({
  selector: 'app-ios-install-banner',
  standalone: true,
  templateUrl: './ios-install-banner.component.html',
  styleUrl: './ios-install-banner.component.css'
})
export class IosInstallBannerComponent {
  readonly pwaInstall = inject(PwaInstallService);

  dismiss(): void {
    this.pwaInstall.dismissIosHint();
  }
}
