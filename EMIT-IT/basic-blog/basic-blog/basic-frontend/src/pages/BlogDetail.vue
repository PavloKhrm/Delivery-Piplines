<template>
  <div>
    <Card>
      <template #title>
        <span class="flex items-center text-2xl font-bold">
          <i class="pi pi-book mr-2"></i>
          {{ post?.title }}
        </span>
      </template>
      <template #content>
        <div v-if="loading" class="flex items-center justify-center text-indigo-600 py-8 text-lg">
          <i class="pi pi-spin pi-spinner mr-2"></i>Loading...
        </div>
        <div v-else>
          <div class="p-4 mb-6 text-lg text-left">{{ post?.content }}</div>
          <div class="flex gap-2">
            <Button v-if="isAuthenticated" label="Edit" icon="pi pi-pencil"
              class="w-full bg-yellow-500 hover:bg-yellow-600 text-white font-medium py-2 px-4 rounded-md transition-colors duration-200 focus:outline-none focus:ring-2 focus:ring-yellow-500 focus:ring-offset-2"
              @click="showEditModal = true" />
            <Button v-if="isAuthenticated" label="Delete" icon="pi pi-trash"
              class="w-full bg-red-600 hover:bg-red-700 text-white font-medium py-2 px-4 rounded-md transition-colors duration-200 focus:outline-none focus:ring-2 focus:ring-red-500 focus:ring-offset-2"
              @click="deletePost" />
          </div>
          <!-- Edit Modal -->
          <Dialog v-model:visible="showEditModal" modal header="Edit Post" :closable="true" style="width: 600px; max-width: 90%;">
            <form @submit.prevent="updatePost">
              <div class="mb-4">
                <label class="block mb-1 font-medium">Title</label>
                <input v-model="editTitle" type="text" class="w-full border rounded px-3 py-2" required autofocus />
              </div>
              <div class="mb-4">
                <label class="block mb-1 font-medium">Content</label>
                <textarea v-model="editContent" class="w-full border rounded px-3 py-2" rows="5" required></textarea>
              </div>
              <div class="flex justify-end gap-2">
                <Button label="Cancel" class="bg-gray-300 text-gray-800 px-4 py-2 rounded"
                  @click="showEditModal = false" type="button" />
                <Button label="Save" icon="pi pi-check"
                  class="bg-green-600 hover:bg-green-700 text-white px-4 py-2 rounded" type="submit" />
              </div>
            </form>
          </Dialog>
        </div>
      </template>
    </Card>
  </div>
</template>

<script setup lang="ts">
import { ref, inject, onMounted } from 'vue';
import { useRoute } from 'vue-router';

const post = ref<any | null>(null);
const loading = ref(true);
const route = useRoute();
const isAuthenticated = inject<{ value: boolean }>('isAuthenticated');

const showEditModal = ref(false);
const editTitle = ref('');
const editContent = ref('');

const BACKEND_URL = import.meta.env.VITE_BACKEND_URL || 'http://localhost:3000';

const fetchPost = async () => {
  loading.value = true;
  try {
    const res = await fetch(`${BACKEND_URL}/blog-post/${route.params.id}`, { credentials: 'include' });
    if (res.ok) {
      post.value = await res.json();
      editTitle.value = post.value?.title || '';
      editContent.value = post.value?.content || '';
    } else {
      post.value = null;
    }
  } finally {
    loading.value = false;
  }
};

const updatePost = async () => {
  const res = await fetch(`${BACKEND_URL}/blog-post/${route.params.id}`, {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
    },
    credentials: 'include',
    body: JSON.stringify({
      title: editTitle.value,
      content: editContent.value,
    }),
  });
  if (res.ok) {
    post.value = await res.json();
    showEditModal.value = false;
  } else {
    alert('Failed to update post');
  }
};

const deletePost = async () => {
  await fetch(`${BACKEND_URL}/blog-post/${route.params.id}`, { method: 'DELETE', credentials: 'include' });

  setTimeout(() => {
    window.location.href = '/';
  }, 500);
};

onMounted(fetchPost);
</script>

<style>
/* No custom styles needed, using utility classes for layout and styling */
</style>
