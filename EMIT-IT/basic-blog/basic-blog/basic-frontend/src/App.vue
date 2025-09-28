<template>
  <div class="app-container">
    <nav class="navbar">
      <Button icon="pi pi-home" :label="isMobile ? '' : 'Home'" @click="goHome" class="nav-btn" />
      <Button icon="pi pi-plus" :label="isMobile ? '' : 'Create'" @click="goCreate" class="nav-btn" v-if="isAuth" />
      <Button icon="pi pi-sign-in" :label="isMobile ? '' : 'Sign In'" @click="goSignIn" class="nav-btn" v-if="!isAuth" />
      <Button icon="pi pi-sign-out" :label="isMobile ? '' : 'Sign Out'" @click="goSignOut" class="nav-btn" v-if="isAuth" />
    </nav>
    <main class="main-content">
      <router-view />
    </main>
  </div>
</template>

<script setup lang="ts">
import { useRouter } from 'vue-router';
import { inject, computed } from 'vue';
import 'primeicons/primeicons.css';
import 'primeflex/primeflex.css';

const router = useRouter();
const isAuthenticated = inject('isAuthenticated') as ReturnType<typeof import('vue')['ref']> | null;
const isAuth = computed(() => isAuthenticated?.value ?? false);

const isMobile = computed(() => {
  if (typeof window !== 'undefined') {
    return window.innerWidth < 640;
  }
  return false;
});

const goHome = () => {
  router.push('/');
};

const goCreate = () => {
  router.push('/create');
};

const goSignIn = () => {
  router.push('/signin');
};

const goSignOut = async () => {
  await fetch('http://localhost:3000/auth/signout', {
    method: 'DELETE',
    credentials: 'include'
  });
  if (isAuthenticated) {
    isAuthenticated.value = false;
  }
  router.push('/signin');
};
</script>

<style scoped>
.app-container {
  min-height: 100vh;
  width: 100%;
}

.navbar {
  display: flex;
  justify-content: center;
  align-items: center;
  padding: 1em 0.5em;
  background: #6366f1;
  box-shadow: 0 2px 8px rgba(99,102,241,0.08);
  border-radius: 0 0 1em 1em;
  gap: 0.25rem;
}

.nav-btn {
  background: #fff;
  color: #6366f1;
  border: 1px solid white !important;
  flex: 1;
  width: 120px;
}

.nav-btn:hover {
  background: #6366f1 !important;
  color: #fff !important;
  border: 1px solid white !important;
}

.main-content {
  width: 100%;
  max-width: 700px;
  margin: 1rem auto;
  padding: 0 1rem;
}

/* Desktop styles */
@media (min-width: 640px) {
  .navbar {
    padding: 2em 0 1em 0;
  }
  
  .nav-btn {
    margin: 0 0.5em;
    flex: none;
    max-width: none;
  }
  
  .main-content {
    margin: 2em auto;
    padding: 0;
  }
}

/* Mobile styles */
@media (max-width: 639px) {
  .nav-btn {
    padding: 0.5rem;
  }
  
  .nav-btn :deep(.p-button-label) {
    display: none;
  }
}
</style>
