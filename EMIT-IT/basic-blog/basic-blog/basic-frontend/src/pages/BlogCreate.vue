<template>
    <div>
        <Card>
            <template #title>
                <span class="create-title">
                    <i class="pi pi-pencil" style="margin-right: 0.5em; color: #6366f1;"></i>
                    Create Blog Post
                </span>
            </template>
            <template #content>
                <form @submit.prevent="submit" class="space-y-6 px-2">
                    <div class="flex flex-col space-y-2">
                        <label for="title" class="text-sm font-medium">Title</label>
                        <InputText id="title" v-model="title"
                            class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                            required />
                    </div>
                    <div class="flex flex-col space-y-2">
                        <label for="content" class="text-sm font-medium">Content</label>
                        <Textarea id="content" v-model="content"
                            class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                            required />
                    </div>
                    <Button label="Create" icon="pi pi-check"
                        class="w-full bg-indigo-600 hover:bg-indigo-700 text-white font-medium py-2 px-4 rounded-md transition-colors duration-200 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2"
                        type="submit" :disabled="isLoading">
                        <i v-if="isLoading" class="pi pi-spin pi-spinner" style="margin-right: 0.5em;"></i>
                    </Button>
                </form>
            </template>
        </Card>
    </div>
</template>

<script setup lang="ts">
import { ref } from 'vue';

const title = ref('');
const content = ref('');
const isLoading = ref(false);

const submit = async () => {
    isLoading.value = true;
    const BACKEND_URL = import.meta.env.VITE_BACKEND_URL || 'http://localhost:3000';
    await fetch(`${BACKEND_URL}/blog-post`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({ title: title.value, content: content.value })
    });

    setTimeout(() => {
        window.location.href = '/';
    }, 500);
};
</script>

<style scoped>
/* No scoped styles needed, using utility classes for layout and styling */
</style>
