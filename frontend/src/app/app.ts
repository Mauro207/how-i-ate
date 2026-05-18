import { Component, signal } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { NavigationCancel, NavigationEnd, NavigationError, NavigationStart, Router, RouterOutlet } from '@angular/router';
import { IosInstallBannerComponent } from './components/ios-install-banner/ios-install-banner.component';
import { AndroidInstallButtonComponent } from './components/android-install-button/android-install-button.component';

@Component({
  selector: 'app-root',
  imports: [RouterOutlet, IosInstallBannerComponent, AndroidInstallButtonComponent],
  templateUrl: './app.html',
  styleUrl: './app.css'
})
export class App {
  protected readonly title = signal('frontend');
  routeLoading = signal(true);

  constructor(private router: Router) {
    this.router.events.pipe(takeUntilDestroyed()).subscribe((event) => {
      if (event instanceof NavigationStart) {
        this.routeLoading.set(true);
      }

      if (
        event instanceof NavigationEnd ||
        event instanceof NavigationCancel ||
        event instanceof NavigationError
      ) {
        this.routeLoading.set(false);
      }
    });
  }
}
