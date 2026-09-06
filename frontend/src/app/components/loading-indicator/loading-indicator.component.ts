import { Component, Input } from '@angular/core';

export type LoadingIndicatorVariant = 'overlay' | 'page' | 'section' | 'inline' | 'button';

@Component({
  selector: 'app-loading-indicator',
  standalone: true,
  templateUrl: './loading-indicator.component.html',
  styleUrl: './loading-indicator.component.css'
})
export class LoadingIndicatorComponent {
  @Input() variant: LoadingIndicatorVariant = 'section';
  @Input() label = 'Caricamento…';
  @Input() detail = '';
}
