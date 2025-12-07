import { Routes } from '@angular/router';
import { LoginComponent } from './components/login/login.component';
import { RestaurantsComponent } from './components/restaurants/restaurants.component';
import { RestaurantCreateComponent } from './components/restaurant-create/restaurant-create.component';
import { RestaurantDetailComponent } from './components/restaurant-detail/restaurant-detail.component';
import { NavigationComponent } from './components/navigation/navigation.component';
import { SettingsComponent } from './components/settings/settings.component';
import { UserRankingsComponent } from './components/user-rankings/user-rankings.component';
import { UsersComponent } from './components/users/users.component';
import { authGuard } from './guards/auth.guard';
import { superadminGuard } from './guards/superadmin.guard';


export const routes: Routes = [
  { path: '', redirectTo: '/login', pathMatch: 'full' },
  { path: 'login', component: LoginComponent },
  { path: 'restaurants', component: RestaurantsComponent, canActivate: [authGuard] },
  { path: 'restaurants/create', component: RestaurantCreateComponent, canActivate: [authGuard] },
  { path: 'restaurants/:id', component: RestaurantDetailComponent, canActivate: [authGuard] },
  { path: 'settings', component: SettingsComponent, canActivate: [authGuard] },
  { path: 'user-rankings/:userId/:username', component: UserRankingsComponent, canActivate: [authGuard] },
  { path: 'users', component: UsersComponent, canActivate: [authGuard, superadminGuard] },
  { path: '**', redirectTo: '/login' }
];
