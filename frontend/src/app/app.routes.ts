import { Routes } from '@angular/router';
import { LoginComponent } from './components/login/login.component';
import { RestaurantsComponent } from './components/restaurants/restaurants.component';
import { RestaurantCreateComponent } from './components/restaurant-create/restaurant-create.component';
import { RestaurantDetailComponent } from './components/restaurant-detail/restaurant-detail.component';
import { NavigationComponent } from './components/navigation/navigation.component';
import { SettingsComponent } from './components/settings/settings.component';
import { UserRankingsComponent } from './components/user-rankings/user-rankings.component';
import { UsersComponent } from './components/users/users.component';
import { RankingsComponent } from './components/rankings/rankings.component';
import { SuggestPlaceComponent } from './components/suggest-place/suggest-place.component';
import { SuggestionsComponent } from './components/suggestions/suggestions.component';
import { SearchComponent } from './components/search/search.component';
import { UpdatesComponent } from './components/updates/updates.component';
import { OpenInWebappComponent } from './components/open-in-webapp/open-in-webapp.component';
import { authGuard } from './guards/auth.guard';
import { superadminGuard } from './guards/superadmin.guard';
import { adminGuard } from './guards/admin.guard';
import { guestGuard } from './guards/guest.guard';


export const routes: Routes = [
  { path: '', redirectTo: '/restaurants', pathMatch: 'full' },
  { path: 'open-in-webapp', component: OpenInWebappComponent },
  { path: 'login', component: LoginComponent, canActivate: [guestGuard] },
  { path: 'restaurants', component: RestaurantsComponent, canActivate: [authGuard] },
  { path: 'restaurants/create', component: RestaurantCreateComponent, canActivate: [authGuard, adminGuard] },
  { path: 'restaurants/:id/edit', component: RestaurantCreateComponent, canActivate: [authGuard, adminGuard] },
  { path: 'restaurants/suggest', component: SuggestPlaceComponent, canActivate: [authGuard] },
  { path: 'restaurants/:id', component: RestaurantDetailComponent, canActivate: [authGuard] },
  { path: 'rankings', component: RankingsComponent, canActivate: [authGuard] },
  { path: 'search', component: SearchComponent, canActivate: [authGuard] },
  { path: 'settings', component: SettingsComponent, canActivate: [authGuard] },
  { path: 'updates', component: UpdatesComponent, canActivate: [authGuard] },

  // Nuova rotta canonical (solo userId)
  { path: 'user-rankings/:userId', component: UserRankingsComponent, canActivate: [authGuard] },

  // Rotta legacy/compat (userId + username)
  { path: 'user-rankings/:userId/:username', component: UserRankingsComponent, canActivate: [authGuard] },

  { path: 'users', component: UsersComponent, canActivate: [authGuard, superadminGuard] },
  { path: 'suggestions', component: SuggestionsComponent, canActivate: [authGuard, adminGuard] },
  { path: '**', redirectTo: '/login' }
];
