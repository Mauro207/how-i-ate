import { Component, OnInit, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { AuthService } from '../../services/auth.service';
import { NavigationComponent } from '../navigation/navigation.component'; 
import { NotificationService } from '../../services/notification.service';
import { SuggestionsBadgeService } from '../../services/suggestions-badge.service';


@Component({
  selector: 'app-settings',
  standalone: true,
  imports: [CommonModule, FormsModule, NavigationComponent],
  templateUrl: './settings.component.html',
  styleUrl: './settings.component.css'
})
export class SettingsComponent implements OnInit {
  displayName = '';
  loading = signal(false);
  successMessage = signal('');
  errorMessage = signal('');

  // Collapsible sections
  accountSectionOpen = signal(true);
  notificationsSectionOpen = signal(false);
  userManagementSectionOpen = signal(false);

    // Notifications
    notificationLoading = signal(false);
    notificationError = signal('');
    testNotificationLoading = signal(false);
    testNotificationResult = signal('');
    testNotificationError = signal('');
  
  // User creation form
  showUserForm = signal(false);
  newUsername = '';
  newEmail = '';
  newPassword = '';
  newUserRole: 'user' | 'admin' = 'user';
  creatingUser = signal(false);
  userCreationSuccess = signal('');
  userCreationError = signal('');

  constructor(
    public authService: AuthService,
    public notificationService: NotificationService,
    public suggestionsBadgeService: SuggestionsBadgeService,
    private router: Router
  ) {}

  ngOnInit(): void {
    const user = this.authService.currentUser();
    if (!user) {
      this.router.navigate(['/login']);
      return;
    }
    this.displayName = user.displayName || '';
    this.notificationService.syncStatus();
    this.suggestionsBadgeService.refreshPendingCount();
  }

  pendingSuggestionsCount(): number {
    return this.suggestionsBadgeService.pendingCount();
  }

  updateDisplayName(): void {
    this.loading.set(true);
    this.successMessage.set('');
    this.errorMessage.set('');

    this.authService.updateProfile(this.displayName).subscribe({
      next: () => {
        this.loading.set(false);
        this.successMessage.set('Nome aggiornato con successo!');
        setTimeout(() => this.successMessage.set(''), 3000);
      },
      error: (err) => {
        this.loading.set(false);
        this.errorMessage.set(err.error?.message || 'Aggiornamento del nome fallito. Per favore riprova.');
        setTimeout(() => this.errorMessage.set(''), 5000);
      }
    });
  }

  logout(): void {
    this.authService.logout();
  }

  goToSuggestions(): void {
    this.router.navigate(['/suggestions']);
  }

  goToUsers(): void {
    this.router.navigate(['/users']);
  }

  goToUpdates(): void {
    this.router.navigate(['/updates']);
  }

  canManageUsers(): boolean {
    const user = this.authService.currentUser();
    return user?.role === 'admin' || user?.role === 'superadmin';
  }

  toggleUserForm(): void {
    this.showUserForm.set(!this.showUserForm());
    if (this.showUserForm()) {
      this.resetUserForm();
    }
  }

  resetUserForm(): void {
    this.newUsername = '';
    this.newEmail = '';
    this.newPassword = '';
    this.newUserRole = 'user';
    this.userCreationSuccess.set('');
    this.userCreationError.set('');
  }

  createNewUser(): void {
    if (!this.newUsername || !this.newEmail || !this.newPassword) {
      this.userCreationError.set('Tutti i campi sono richiesti');
      return;
    }

    this.creatingUser.set(true);
    this.userCreationSuccess.set('');
    this.userCreationError.set('');

    const createObservable = this.newUserRole === 'admin' 
      ? this.authService.createAdmin(this.newUsername, this.newEmail, this.newPassword)
      : this.authService.createUser(this.newUsername, this.newEmail, this.newPassword);

    createObservable.subscribe({
      next: (response) => {
        this.creatingUser.set(false);
        this.userCreationSuccess.set(`${this.newUserRole === 'admin' ? 'Admin' : 'User'} creato con successo!`);
        setTimeout(() => {
          this.resetUserForm();
          this.showUserForm.set(false);
        }, 2000);
      },
      error: (err) => {
        this.creatingUser.set(false);
        this.userCreationError.set(err.error?.message || 'Creazione dell\'utente fallita. Per favore riprova.');
      }
    });
  }

  get notificationsSupported(): boolean {
    return this.notificationService.isSupported;
  }

  /** Mostra la sezione anche su Safari o browser senza Push API completa */
  get notificationsUIVisible(): boolean {
    return this.notificationService.isUIVisible;
  }

  get notificationPermissionDenied(): boolean {
    return this.notificationService.permissionState === 'denied';
  }

  async toggleNotifications(): Promise<void> {
    this.notificationLoading.set(true);
    this.notificationError.set('');
    try {
      if (this.notificationService.notificationsEnabled()) {
        await this.notificationService.disable();
      } else {
        await this.notificationService.enable();
      }
    } catch (err: any) {
      this.notificationError.set(err.message || 'Errore nella gestione delle notifiche.');
    } finally {
      this.notificationLoading.set(false);
    }
  }

  async sendTestNotification(): Promise<void> {
    this.testNotificationLoading.set(true);
    this.testNotificationResult.set('');
    this.testNotificationError.set('');
    try {
      await this.notificationService.sendTestNotification();
      this.testNotificationResult.set('Notifica di prova inviata! Controlla le notifiche del dispositivo.');
      setTimeout(() => this.testNotificationResult.set(''), 5000);
    } catch (err: any) {
      this.testNotificationError.set(err?.error?.message || 'Errore durante l\'invio della notifica di prova.');
      setTimeout(() => this.testNotificationError.set(''), 5000);
    } finally {
      this.testNotificationLoading.set(false);
    }
  }

  isSuperAdmin(): boolean {
    return this.authService.currentUser()?.role === 'superadmin';
  }

  toggleAccountSection(): void {
    this.accountSectionOpen.set(!this.accountSectionOpen());
  }

  toggleNotificationsSection(): void {
    this.notificationsSectionOpen.set(!this.notificationsSectionOpen());
  }

  toggleUserManagementSection(): void {
    this.userManagementSectionOpen.set(!this.userManagementSectionOpen());
  }
}
