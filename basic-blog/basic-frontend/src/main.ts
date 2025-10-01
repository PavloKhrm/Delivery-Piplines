import { createApp, ref } from 'vue';
import './style.css';
import App from './App.vue';
import router from './router';
import PrimeVue from "primevue/config";
import Theme from '@primeuix/themes/aura';

// Simple global auth state
const hasCheckedSession = ref(false);
const isAuthenticated = ref(false);
const user = ref(null);

// Check API availability via health endpoint
async function checkAuth() {
    try {
        const res = await fetch('/api/health', {
            credentials: 'include',
        });
        isAuthenticated.value = res.ok;
        
        if (isAuthenticated.value) {
            console.log('API health ok');
        }
    } catch {
        isAuthenticated.value = false;
    }
}

// Global router guard for this frontend app
router.beforeEach(async (to, _from, next) => {
    try {
        if (!hasCheckedSession.value) {
            await checkAuth();
        }

        // These are publicly accessible routes
        if (to.path === '/' || to.path === '/signin' || to.path.startsWith('/post')) {
            return to;
        }

        // No need to recheck if user is already authenticated
        if (hasCheckedSession.value && isAuthenticated.value) {
            return to;
        }


        if (!isAuthenticated.value) {
            router.replace('/signin');

            return false;
        }
    } catch {
        //
    } finally {
        hasCheckedSession.value = true;

        // Always need to call `next()`
        next();
    }
})

const app = createApp(App);

app.provide('isAuthenticated', isAuthenticated);
app.provide('user', user);
app.use(router);
app.use(PrimeVue, {
    theme: {
        preset: Theme
    }
});

app.mount('#app');
