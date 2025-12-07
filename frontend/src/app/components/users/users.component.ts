import { Component, OnInit, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { AuthService, User } from '../../services/auth.service';
import { NavigationComponent } from '../navigation/navigation.component';

interface FeedbackEntry {
  type: 'success' | 'error';
  message: string;
}

@Component({
  selector: 'app-users',
  standalone: true,
  imports: [CommonModule, FormsModule, NavigationComponent],
  templateUrl: './users.component.html',
  styleUrls: ['./users.component.css']
})
export class UsersComponent implements OnInit {
  users = signal<User[]>([]);
  loading = signal(true);
  error = signal('');
  savingId = signal<string | null>(null);
  passwordInputs = signal<Record<string, string>>({});
  feedback = signal<Record<string, FeedbackEntry>>({});

  constructor(private authService: AuthService) {}

  ngOnInit(): void {
    this.loadUsers();
  }

  loadUsers(): void {
    this.loading.set(true);
    this.error.set('');
    this.authService.getAllUsers().subscribe({
      next: (resp) => {
        this.users.set(resp.users || []);
        this.loading.set(false);
      },
      error: (err) => {
        this.error.set(err.error?.message || 'Errore nel caricamento utenti');
        this.loading.set(false);
      }
    });
  }

  onPasswordInput(userId: string, value: string): void {
    this.passwordInputs.set({ ...this.passwordInputs(), [userId]: value });
    const { [userId]: _removed, ...rest } = this.feedback();
    this.feedback.set(rest);
  }

  updatePassword(userId: string): void {
    const pwd = (this.passwordInputs()[userId] || '').trim();
    if (pwd.length < 6) {
      this.setFeedback(userId, 'error', 'La password deve avere almeno 6 caratteri.');
      return;
    }

    this.savingId.set(userId);
    this.authService.updateUserPassword(userId, pwd).subscribe({
      next: (resp) => {
        this.setFeedback(userId, 'success', resp.message || 'Password aggiornata');
        this.passwordInputs.set({ ...this.passwordInputs(), [userId]: '' });
        this.savingId.set(null);
      },
      error: (err) => {
        this.setFeedback(userId, 'error', err.error?.message || 'Errore nell\'aggiornamento della password');
        this.savingId.set(null);
      }
    });
  }

  private setFeedback(userId: string, type: 'success' | 'error', message: string): void {
    this.feedback.set({ ...this.feedback(), [userId]: { type, message } });
  }
}
