<template>
    <div>
        <Card>
            <template #title>Blog Posts</template>
            <template #content>
                <input ref="searchInput" v-model="query" placeholder="Search..." class="border p-2 mb-4 rounded" />
                <div v-if="loading">Loading...</div>
                <div class="h-[450px]" v-else>
                    <div v-for="post in data?.data" :key="post.id" class="p-mb-2">
                        <router-link :to="`/post/${post.id}`">
                            <Card class="text-left border-[0.5px] mb-2 h-[150px]">
                                <template #title>
                                    <div class="truncate">{{ post.title }}</div>
                                </template>
                                <template #content>
                                    <div class="overflow-hidden text-ellipsis line-clamp-3">
                                        {{ truncate(post.content, 200) }}
                                    </div>
                                </template>
                            </Card>
                        </router-link>
                    </div>
                </div>
                <Paginator :rows="limit" :totalRecords="data?.meta.totalItems || 0"
                    :first="((data?.meta?.currentPage ?? 1) - 1) * limit" @page="handlePageChange"
                    template="FirstPageLink PrevPageLink PageLinks NextPageLink LastPageLink"
                    class="paginator-ticker" />
            </template>
        </Card>
    </div>
</template>

<script setup lang="ts">
import { onMounted, ref, watch } from 'vue';
import { debounce } from 'lodash-es';

interface CustomPaginateMeta {
    totalItems: number;
    itemsPerPage: number;
    totalPages: number;
    currentPage: number;
}

interface CustomPaginated<T> {
    data: T[];
    meta: CustomPaginateMeta;
}

interface BlogPost {
    id: number;
    title: string;
    content: string;
    createdAt: string;
    updatedAt: string;
}

const data = ref<CustomPaginated<BlogPost>>();
const loading = ref(true);
const query = ref('');
const page = ref(1);
const limit = ref(3);
const searchInput = ref<HTMLInputElement>();

const fetchPosts = async () => {
    try {
        const res = await fetch(`/api/blog-post?query=${query.value}&page=${page.value}&limit=${limit.value}`, { credentials: 'include' });
        data.value = await res.json();
    } finally {
        loading.value = false;
        // Keep focus on search input after results load
        if (searchInput.value) {
            searchInput.value.focus();
        }
    }
};

const debouncedFetchPosts = debounce(fetchPosts, 500);

function truncate(text: string, length: number) {
    if (!text) return '';
    return text.length > length ? text.substring(0, length) + '...' : text;
}

watch(query, debouncedFetchPosts);

onMounted(fetchPosts);

const handlePageChange = (event: any) => {
    page.value = Math.floor(event.first / limit.value) + 1;
    loading.value = true;
    fetchPosts();
};
</script>

<style>
.paginator-ticker {
    margin-top: 2rem;
    display: flex;
    justify-content: center;
}
</style>
