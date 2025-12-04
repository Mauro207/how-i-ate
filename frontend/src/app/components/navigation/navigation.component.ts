import { Component } from '@angular/core';
import { AuthService } from '../../services/auth.service';
import { RouterLink } from '@angular/router';
import { Router } from '@angular/router';
import { CommonModule } from '@angular/common';

  

@Component({
  selector: 'app-navigation',
  templateUrl: './navigation.component.html',
  styleUrls: ['./navigation.component.css'],
  imports: [ RouterLink, CommonModule ] 
})
export class NavigationComponent {
  menuOpen = false; // Stato del menu dropdown
  constructor(public authService: AuthService, private router: Router) {}

  logout() {
    this.authService.logout();
  }

  isActive(url: string): boolean {
    return this.router.url === url; 
  }

  toggleMenu(): void {
    this.menuOpen = !this.menuOpen; // Alterna lo stato del menu
  }
}