import { CommonModule } from '@angular/common';
import { Component, OnInit, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { Title } from '@angular/platform-browser';
import { AuthService } from '../../services/auth.service';

@Component({
  selector: 'app-register',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink],
  templateUrl: './register.component.html',
  styleUrl: './register.component.css'
})
export class RegisterComponent implements OnInit {
  name = '';
  email = '';
  password = '';
  invitationToken = '';
  inviterName = signal('');
  checkingInvitation = signal(true);
  invalidInvitation = signal(false);
  loading = signal(false);
  error = signal('');
  showPassword = signal(false);

  constructor(
    private auth: AuthService,
    private route: ActivatedRoute,
    private router: Router,
    private title: Title
  ) {}

  ngOnInit(): void {
    this.title.setTitle('Registrati - How I Ate');
    this.invitationToken = this.route.snapshot.queryParamMap.get('invite') || '';
    if (!this.invitationToken) {
      this.invalidInvitation.set(true);
      this.checkingInvitation.set(false);
      return;
    }

    this.auth.previewInvitation(this.invitationToken).subscribe({
      next: response => {
        this.inviterName.set(response.inviter.name);
        this.checkingInvitation.set(false);
      },
      error: () => {
        this.invalidInvitation.set(true);
        this.checkingInvitation.set(false);
      }
    });
  }

  onSubmit(): void {
    if (!this.name.trim() || !this.email.trim() || this.password.length < 6) {
      this.error.set('Compila tutti i campi. La password deve avere almeno 6 caratteri.');
      return;
    }
    this.loading.set(true);
    this.error.set('');
    this.auth.register(this.name, this.email, this.password, this.invitationToken).subscribe({
      next: () => this.router.navigate(['/restaurants']),
      error: err => {
        this.loading.set(false);
        this.error.set(err.error?.message || 'Registrazione non riuscita. Riprova.');
      }
    });
  }
}
