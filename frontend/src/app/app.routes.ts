import { Routes } from '@angular/router';
import { LoginComponent } from './components/login/login.component';
import { RestaurantsComponent } from './components/restaurants/restaurants.component';
import { RestaurantCreateComponent } from './components/restaurant-create/restaurant-create.component';
import { RestaurantDetailComponent } from './components/restaurant-detail/restaurant-detail.component';

export const routes: Routes = [
  { path: '', redirectTo: '/login', pathMatch: 'full' },
  { path: 'login', component: LoginComponent },
  { path: 'restaurants', component: RestaurantsComponent },
  { path: 'restaurants/create', component: RestaurantCreateComponent },
  { path: 'restaurants/:id', component: RestaurantDetailComponent },
  { path: '**', redirectTo: '/login' }
];
