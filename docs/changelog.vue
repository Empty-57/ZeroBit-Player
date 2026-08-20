
<template>
  <div>
    <!-- 加载中 -->
    <div v-if="loading" class="custom-block tip">
      <p class="custom-block-title">加载中</p>
      <p>正在获取最新版本日志，请稍候...</p>
    </div>

    <!-- 错误提示 -->
    <div v-else-if="error" class="custom-block danger">
      <p class="custom-block-title">错误</p>
      <p>{{ error }}</p>
    </div>

    <!-- 日志列表 -->
    <div v-else class="changelog-container">
      <div v-for="item in releases" :key="item.id" class="release-card">
        <div class="release-header">
          <span class="release-tag"><a :href="item.html_url" target="_blank" rel="noopener noreferrer">
              {{ item.tag_name }}
            </a></span>
          <span class="release-date">{{ formatDate(item.published_at) }}</span>
        </div>

        <!-- 富文本 Markdown -->
        <div
          class="release-content vp-doc"
          v-html="renderMarkdown(item.body)"
        ></div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { marked } from 'marked'

const releases = ref([])
const loading = ref(true)
const error = ref('')

const API_URL = `https://api.github.com/repos/Empty-57/Zerobit-Player/releases?per_page=10`

const formatDate = (dateStr) => {
  if (!dateStr) return ''
  const date = new Date(dateStr)
  return date.toLocaleDateString('zh-CN', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit'
  })
}

const renderMarkdown = (content) => {
  if (!content) return '<p>暂无详细更新说明</p>'
  return marked.parse(content)
}

const fetchReleases = async () => {
  try {
    loading.value = true
    const res = await fetch(API_URL)
    if (!res.ok) throw new Error(`请求失败: ${res.content}`)
    releases.value = await res.json()
  } catch (err) {
    error.value = err.message || '获取更新日志失败'
  } finally {
    loading.value = false
  }
}

onMounted(() => {
  fetchReleases()
})
</script>

<style scoped>
.changelog-container {
  margin-top: 2rem;
}
.release-card {
  border-bottom: 1px solid var(--vp-c-divider);
  padding-bottom: 2rem;
  margin-bottom: 2.5rem;
}
.release-header {
  display: flex;
  align-items: center;
  gap: 12px;
  flex-wrap: wrap;
  margin-bottom: 1.2rem;
}
.release-tag {
  background-color: var(--vp-c-brand-soft);
  color: var(--vp-c-brand-1);
  padding: 4px 8px;
  border-radius: 4px;
  font-size: 1rem;
  font-weight: bold;
}
.release-tag a {
  text-decoration: none !important;
}
.release-date {
  color: var(--vp-c-text-2);
  font-size: 0.9rem;
}
.release-content {
  background-color: var(--vp-c-bg-soft);
  padding: 1.2rem 1.5rem;
  border-radius: 8px;
}
.release-content :deep(h1),
.release-content :deep(h2),
.release-content :deep(h3) {
  margin-top: 1rem;
  margin-bottom: 0.5rem;
  border-top: none;
  padding-top: 0;
}
.release-content :deep(p:first-child) {
  margin-top: 0;
}
.release-content :deep(p:last-child) {
  margin-bottom: 0;
}
.release-content :deep(ul),
.release-content :deep(ol) {
  padding-left: 1.2rem;
}
</style>