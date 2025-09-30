import { createRouter, createWebHistory } from 'vue-router';
import BlogList from './pages/BlogList.vue';
import BlogDetail from './pages/BlogDetail.vue';
import BlogCreate from './pages/BlogCreate.vue';
import SignIn from './pages/SignIn.vue';

const routes = [
  { path: '/', component: BlogList },
  { path: '/post/:id', component: BlogDetail },
  { path: '/create', component: BlogCreate },
  { path: '/signin', component: SignIn },
];

const router = createRouter({
  history: createWebHistory(),
  routes,
});

export default router;
