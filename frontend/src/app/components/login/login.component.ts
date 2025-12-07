import { Component, signal, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router, RouterLink, ActivatedRoute } from '@angular/router';
import { AuthService } from '../../services/auth.service';
import { Title } from '@angular/platform-browser';

@Component({
  selector: 'app-login',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink],
  templateUrl: './login.component.html',
  styleUrl: './login.component.css'
})
export class LoginComponent implements OnInit {
  email = signal('');
  password = signal('');
  error = signal('');
  loading = signal(false);
  private returnUrl = '/restaurants';

  constructor(
    private authService: AuthService,
    private router: Router,
    private route: ActivatedRoute,
    private title: Title
  ) {}

  ngOnInit(): void {
    // Get return URL from route parameters or default to '/restaurants'
    this.returnUrl = this.route.snapshot.queryParams['returnUrl'] || '/restaurants';
    this.title.setTitle('Effettua l\'accesso - How I Ate');
  }

  onSubmit(): void {
    if (!this.email() || !this.password()) {
      this.error.set('Per favore compila i campi.');
      return;
    }

    this.loading.set(true);
    this.error.set('');

    this.authService.login(this.email(), this.password()).subscribe({
      next: () => {
        this.router.navigate([this.returnUrl]);
      },
      error: (err) => {
        this.loading.set(false);
        this.error.set(err.error?.message || 'Accesso fallito. Per favore riprova.');
      }
    });
  }
}
