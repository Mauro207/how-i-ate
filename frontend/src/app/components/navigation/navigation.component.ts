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
    this.menuOpen = !this.menuOpen; 
  }

  goToMyRankings(): void {
    const user = this.authService.currentUser();
    if (!user) {
      // se vuoi puoi reindirizzare al login
      this.router.navigate(['/login']);
      return;
    }

    const userId = user.id; // dipende da come è fatto il tuo user
    const username = user.username || 'Utente';

    this.router.navigate(['/user-rankings', userId, username]);
  }
}