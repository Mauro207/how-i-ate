import { CommonModule } from '@angular/common';
import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';

@Component({
  selector: 'app-open-in-webapp',
  standalone: true,
  imports: [CommonModule, RouterLink],
  templateUrl: './open-in-webapp.component.html',
  styleUrl: './open-in-webapp.component.css'
})
export class OpenInWebappComponent implements OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);

  readonly targetPath = signal('/restaurants');

  readonly isStandalone = computed(() => {
    if (typeof window === 'undefined') {
      return false;
    }

    return window.matchMedia('(display-mode: standalone)').matches ||
      ((window.navigator as Navigator & { standalone?: boolean }).standalone === true);
  });

  readonly isLikelySafari = computed(() => {
    if (typeof window === 'undefined') {
      return false;
    }

    const ua = window.navigator.userAgent;
    return /Safari/i.test(ua) && !/Chrome|Chromium|CriOS|Edg|OPR|FxiOS|Firefox/i.test(ua);
  });

  ngOnInit(): void {
    const target = this.route.snapshot.queryParamMap.get('target') || '/restaurants';
    const normalized = target.startsWith('/') ? target : '/restaurants';
    this.targetPath.set(normalized);

    if (this.isStandalone()) {
      this.router.navigateByUrl(normalized);
    }
  }
}
