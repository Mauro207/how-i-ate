import { Component, DestroyRef, ElementRef, Input, OnInit, ViewChild, inject, signal } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { AuthService } from '../../services/auth.service';

@Component({
  selector: 'app-invite',
  standalone: true,
  templateUrl: './invite.component.html',
  styleUrl: './invite.component.css'
})
export class InviteComponent implements OnInit {
  @Input() floating = false;
  @ViewChild('dialog', { static: true }) dialog!: ElementRef<HTMLDialogElement>;
  private auth = inject(AuthService);
  private destroyRef = inject(DestroyRef);
  visible = signal(false);
  dismissing = signal(false);
  loading = signal(false);
  link = signal('');
  error = signal('');
  promptError = signal('');
  copied = signal(false);

  ngOnInit(): void {
    if (this.floating) {
      this.auth.getInvitationStatus().pipe(takeUntilDestroyed(this.destroyRef)).subscribe({
        next: status => this.visible.set(!status.dismissed),
        error: () => this.visible.set(false)
      });
    }
  }

  dismiss(): void {
    if (this.dismissing()) return;
    this.dismissing.set(true);
    this.promptError.set('');
    this.auth.dismissInvitationPrompt().pipe(takeUntilDestroyed(this.destroyRef)).subscribe({
      next: () => { this.visible.set(false); this.dismissing.set(false); },
      error: () => { this.promptError.set('Impossibile salvare. Riprova a chiudere.'); this.dismissing.set(false); }
    });
  }

  open(): void {
    this.dialog.nativeElement.showModal();
    this.copied.set(false);
    this.error.set('');
    if (this.link()) return;
    this.loading.set(true);
    this.auth.getInvitation().pipe(takeUntilDestroyed(this.destroyRef)).subscribe({
      next: invitation => {
        const url = new URL('register', document.baseURI);
        url.searchParams.set('invite', invitation.token);
        this.link.set(url.href);
        this.loading.set(false);
      },
      error: err => {
        this.error.set(err.error?.message || 'Impossibile creare il link. Chiudi e riprova.');
        this.loading.set(false);
      }
    });
  }

  async copy(input: HTMLInputElement): Promise<void> {
    try {
      await navigator.clipboard.writeText(this.link());
      this.copied.set(true);
      this.error.set('');
    } catch {
      input.focus();
      input.select();
      this.error.set('Copia automatica non disponibile. Seleziona e copia il link qui sopra.');
    }
  }

  close(): void { this.dialog.nativeElement.close(); }
}
