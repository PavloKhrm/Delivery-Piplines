<template>
  <div>
    <Card>
      <template #title>Sign In</template>
      <template #content>
        <form @submit.prevent="submit" class="space-y-6 px-2">
          <div class="flex flex-col space-y-2">
            <label for="username" class="text-sm font-medium">Username</label>
            <InputText id="username" v-model="username"
              class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
              required />
          </div>
          <div class="flex flex-col space-y-2">
            <label for="password" class="text-sm font-medium">Password</label>
            <InputText id="password" v-model="password" type="password"
              class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
              required />
          </div>
          <Button label="Sign In" icon="pi pi-sign-in"
            class="w-full bg-indigo-600 hover:bg-indigo-700 text-white font-medium py-2 px-4 rounded-md transition-colors duration-200 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2"
            type="submit" />
        </form>
      </template>
    </Card>
  </div>
</template>

<script setup lang="ts">
import { ref, inject, onBeforeMount } from 'vue';
import { useRouter } from 'vue-router';
const username = ref('');
const password = ref('');
const router = useRouter();
const isAuthenticated = inject<{ value: boolean }>('isAuthenticated');
const user = inject<{ value: { username: string | null } | null }>('user');

const submit = async () => {
  const BACKEND_URL = import.meta.env.VITE_BACKEND_URL || 'http://localhost:3000';
  const res = await fetch(`${BACKEND_URL}/auth/signin`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    credentials: 'include',
    body: JSON.stringify({ username: username.value, password: password.value })
  });
  if (res.ok) {
    isAuthenticated && (isAuthenticated.value = true);
    user && (user.value = await res.json());
    router.push('/');
  } else {
    isAuthenticated && (isAuthenticated.value = false);
    user && (user.value = null);
    alert('Login failed');
  }
};

onBeforeMount(() => {
  if (isAuthenticated?.value) {
    router.replace('/');
  }
})
</script>

<style>
.btn {
  background: #fff;
  color: #6366f1;
  margin: 0 0.5em;
  border: 1px solid white !important;
}

.btn:hover {
  background: #6366f1 !important;
  color: #fff !important;
  border: 1px solid white !important;
}
</style>