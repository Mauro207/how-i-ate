import { Component, OnInit, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { AuthService } from '../../services/auth.service';
import { NavigationComponent } from '../navigation/navigation.component'; 


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
  
  // User creation form
  showUserForm = signal(false);
  newUsername = signal('');
  newEmail = signal('');
  newPassword = signal('');
  newUserRole = signal<'user' | 'admin'>('user');
  creatingUser = signal(false);
  userCreationSuccess = signal('');
  userCreationError = signal('');

  constructor(
    public authService: AuthService,
    private router: Router
  ) {}

  ngOnInit(): void {
    const user = this.authService.currentUser();
    if (!user) {
      this.router.navigate(['/login']);
      return;
    }
    this.displayName = user.displayName || '';
  }

  updateDisplayName(): void {
    this.loading.set(true);
    this.successMessage.set('');
    this.errorMessage.set('');

    this.authService.updateProfile(this.displayName).subscribe({
      next: () => {
        this.loading.set(false);
        this.successMessage.set('Display name updated successfully!');
        setTimeout(() => this.successMessage.set(''), 3000);
      },
      error: (err) => {
        this.loading.set(false);
        this.errorMessage.set(err.error?.message || 'Failed to update display name');
        setTimeout(() => this.errorMessage.set(''), 5000);
      }
    });
  }

  logout(): void {
    this.authService.logout();
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
    this.newUsername.set('');
    this.newEmail.set('');
    this.newPassword.set('');
    this.newUserRole.set('user');
    this.userCreationSuccess.set('');
    this.userCreationError.set('');
  }

  createNewUser(): void {
    if (!this.newUsername() || !this.newEmail() || !this.newPassword()) {
      this.userCreationError.set('All fields are required');
      return;
    }

    this.creatingUser.set(true);
    this.userCreationSuccess.set('');
    this.userCreationError.set('');

    const createObservable = this.newUserRole() === 'admin' 
      ? this.authService.createAdmin(this.newUsername(), this.newEmail(), this.newPassword())
      : this.authService.createUser(this.newUsername(), this.newEmail(), this.newPassword());

    createObservable.subscribe({
      next: (response) => {
        this.creatingUser.set(false);
        this.userCreationSuccess.set(`${this.newUserRole() === 'admin' ? 'Admin' : 'User'} created successfully!`);
        setTimeout(() => {
          this.resetUserForm();
          this.showUserForm.set(false);
        }, 2000);
      },
      error: (err) => {
        this.creatingUser.set(false);
        this.userCreationError.set(err.error?.message || 'Failed to create user');
      }
    });
  }

  isSuperAdmin(): boolean {
    return this.authService.currentUser()?.role === 'superadmin';
  }
}
