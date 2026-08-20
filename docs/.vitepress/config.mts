import { defineConfig } from 'vitepress'

// https://empty-57.github.io/ZeroBit-Player/
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
    outline: {
      level: 'deep',
      label: '页面导航',
    },
    sidebar: {
      '/guide/':[
      {
        base: '/guide',
        text: '开始',
        items: [
          { text: '简介', link: '/' },
          { text: '安装', link: '/install' },
          { text: '快速上手', link: '/quickstart' }
        ]
      },
        {
          base: '/guide',
        text: '功能',
        items: [
          { text: '音乐库', link: '/library' },
          { text: '播放与音频', link: '/player' },
          { text: '歌词', link: '/lyrics' },
          { text: '桌面歌词', link: '/desktop-lyric' },
          { text: '交互与手势', link: '/interactions' },
          { text: '外观与设置', link: '/settings' },
        ]
      },
        {
          base: '/guide',
        text: '社区',
        items: [
          { text: '贡献指南', link: '/contribute' },
          { text: '致谢', link: '/credits' },
          { text: '更新日志', link: '/changelog' }
        ]
      },
          {
            base: '/guide',
          text: '帮助',
          items: [
            { text: '常见问题', link: '/faq' },
            { text: '快捷键', link: '/hotkeys' }
          ]
        }
    ],
      '/dev/': [
        {
          base:'/dev',
          text: '开发',
          items: [
            { text: '架构', link: '/' },
            { text: '构建', link: '/build' }
          ]
        }
      ]
    },
    nav: [
      { text: '首页', link: '/' },
      {
        text: '指南',
        items: [
          { text: '简介', link: '/guide/' },
          { text: '安装', link: '/guide/install' },
          { text: '快速上手', link: '/guide/quickstart' },
          { text: '常见问题', link: '/guide/faq' }
        ]
      },
      {
        text: '功能',
        items: [
          { text: '音乐库', link: '/guide/library' },
          { text: '播放与音频', link: '/guide/player' },
          { text: '歌词', link: '/guide/lyrics' },
          { text: '桌面歌词', link: '/guide/desktop-lyric' },
          { text: '交互与手势', link: '/guide/interactions' },
          { text: '外观与设置', link: '/guide/settings' }
        ]
      },
      {
        text: '社区',
        items: [
          { text: '贡献指南', link: '/guide/contribute' },
          { text: '致谢', link: '/guide/credits' },
          { text: '更新日志', link: '/guide/changelog' }
        ]
      },
      {
        text: '开发',
        items: [
          { text: '架构', link: '/dev/' },
          { text: '构建', link: '/dev/build' }
        ]
      },
      { text: '下载', link: '/download' }
    ],

    socialLinks: [
      { icon: 'github', link: 'https://github.com/Empty-57/ZeroBit-Player' },
      { icon: 'gitee', link: 'https://gitee.com/empty-57/ZeroBit-Player' },
      { icon: 'bilibili', link: 'https://space.bilibili.com/472859740' },
    ],
    footer: {
      message: '基于 GPL-3.0 协议发布',
      copyright: `Copyright © <a href="https://github.com/Empty-57/ZeroBit-Player">ZeroBit Player</a> ${new Date().getFullYear()} by <a href="https://github.com/Empty-57">Empty-57</a>`,
    },
    notFound: {
      code: '404',
      title: '页面不存在',
      quote: '但如果你不改变方向，继续寻找，最终可能会到达你想要去的地方……',
      linkLabel: '回到首页',
      linkText: '回到首页'
    },
    darkModeSwitchLabel: '外观',
    lightModeSwitchTitle: '切换到浅色模式',
    darkModeSwitchTitle: '切换到深色模式',
    returnToTopLabel: '回到顶部',
    sidebarMenuLabel: '菜单',
    langMenuLabel: '切换语言',
    skipToContentLabel: '跳到正文',
    docFooter: {
      prev: '上一页',
      next: '下一页'
    }
  }
})
