import { defineConfig } from 'vitepress'

export default defineConfig({
  title: "Zerobit Player",
  description: "Zerobit Player Document",
  base: '/ZeroBit-Player/',
  head: [['link', { rel: 'icon', href: '/ZeroBit-Player/app_icon.ico' }]],
  lastUpdated: true,
  lang: 'zh-CN',
  themeConfig: {
    logo: '/app_icon.png',
    search: {
      provider: 'local',
      options: {
        locales: {
          root: {
            translations: {
              button: {
                buttonText: '搜索',
                buttonAriaLabel: '搜索'
              },
              modal: {
                displayDetails: '显示详细列表',
                resetButtonTitle: '重置搜索',
                backButtonTitle: '关闭搜索',
                noResultsText: '没有结果',
                footer: {
                  selectText: '选择',
                  selectKeyAriaLabel: '输入',
                  navigateText: '导航',
                  navigateUpKeyAriaLabel: '上箭头',
                  navigateDownKeyAriaLabel: '下箭头',
                  closeText: '关闭',
                  closeKeyAriaLabel: 'Esc'
                }
              }
            }
          }
        }
      }
    },
    editLink: {
      pattern: 'https://github.com/empty-57/ZeroBit-Player/edit/master/docs/:path',
      text: '在 GitHub 上编辑此页'
    },
    nav: [
      { text: '首页', link: '/' },
        {
        text: '指南',
        items: [
          { text: 'Item A', link: '/' },
          { text: 'Item B', link: '/' },
          { text: 'Item C', link: '/' }
        ]
      },
      { text: '下载', link: '/download-page' }
    ],

    sidebar: [
      {
        text: 'tt',
        items: [
          { text: 's1', link: '/' },
          { text: 's2', link: '/' }
        ]
      }
    ],

    socialLinks: [
      { icon: 'github', link: 'https://github.com/Empty-57/ZeroBit-Player' },
      { icon: 'gitee', link: 'https://gitee.com/empty-57/ZeroBit-Player' },
      { icon: 'bilibili', link: 'https://space.bilibili.com/472859740' },
    ],
    footer: {
      message: '基于 GPL-3.0 协议发布',
      copyright: `Copyright © <a href="https://github.com/Empty-57/ZeroBit-Player">ZeroBit Player</a> ${new Date().getFullYear()} by <a href="https://github.com/Empty-57">Empty-57</a>`,
    }
  }
})
