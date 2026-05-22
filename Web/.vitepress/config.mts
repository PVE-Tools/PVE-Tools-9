import { defineConfig, type HeadConfig } from 'vitepress'

const SITE_URL = 'https://pve.oowo.cc'
const SITE_NAME = 'PVE Tools Pro'
const SITE_DESCRIPTION = 'PVE Tools Pro 是面向 Proxmox VE 9.x 的一键运维脚本，覆盖换源、系统维护、VM 生命周期、宿主机网络、防火墙、IPv6、GPU 与 PCI 直通。'
const DEFAULT_OG_IMAGE = `${SITE_URL}/og-image.png`

function pageToUrl(page: string): string {
  const normalized = page
    .replace(/(^|\/)index\.md$/, '$1')
    .replace(/\.md$/, '')

  if (!normalized) {
    return `${SITE_URL}/`
  }

  return `${SITE_URL}/${normalized}`
}

export default defineConfig({
  lang: 'zh-CN',
  title: SITE_NAME,
  titleTemplate: ':title | PVE Tools Pro',
  description: SITE_DESCRIPTION,
  cleanUrls: true,
  lastUpdated: true,
  ignoreDeadLinks: 'localhostLinks',
  vite: {
    plugins: [
      {
        name: 'skip-unused-fonts',
        generateBundle(_options, bundle) {
          // 项目主要使用 HarmonyOS Sans，Inter 仅作回退
          // 仅保留 latin 和 latin-ext 子集，移除 cyrillic/greek/vietnamese 等
          const keep = /inter-(roman|italic)-(latin|latinext)/i
          for (const fileName of Object.keys(bundle)) {
            if (/inter.*\.woff2$/i.test(fileName) && !keep.test(fileName)) {
              delete bundle[fileName]
            }
          }
        }
      }
    ]
  },
  sitemap: {
    hostname: SITE_URL,
    lastmodDateOnly: true,
    transformItems: (items) => items.map((item) => {
      const path = item.url.startsWith('http')
        ? new URL(item.url).pathname
        : item.url.startsWith('/')
          ? item.url
          : `/${item.url}`

      return {
        ...item,
        changefreq: path === '/' ? 'weekly' : 'monthly',
        priority: path === '/' ? 1 : path.startsWith('/advanced/') ? 0.7 : 0.8
      }
    })
  },
  srcExclude: ['CLAUDE.md'],
  head: [
    ['link', { rel: 'icon', href: '/logo.svg', type: 'image/svg+xml' }],
    ['meta', { name: 'author', content: 'Maple' }],
    ['meta', { name: 'keywords', content: 'PVE Tools Pro, PVE-Tools-9, Proxmox VE 9, Proxmox, PVE 运维脚本, 虚拟机管理, GPU 直通, PCI 直通, IPv6, 防火墙' }],
    ['meta', { name: 'robots', content: 'index,follow,max-image-preview:large' }],
    ['meta', { property: 'og:site_name', content: SITE_NAME }],
    ['meta', { property: 'og:locale', content: 'zh_CN' }],
    ['meta', { name: 'twitter:card', content: 'summary_large_image' }],
    ['meta', { name: 'twitter:site', content: '@Mapleawaa' }],
    // ['link', { rel: 'stylesheet', href: 'https://s1.hdslb.com/bfs/static/jinkela/longtu/images/harmonyos_sans_sc.css' }],
    // ['link', { rel: 'stylesheet', href: 'https://s1.hdslb.com/bfs/static/jinkela/longtu/images/harmonyos_sans_sc_mono.css' }]
  ],
  transformHead({ page, title, description }) {
    const url = pageToUrl(page)
    const pageTitle = title || SITE_NAME
    const pageDescription = description || SITE_DESCRIPTION
    const isArticle = page.startsWith('advanced/')

    const head: HeadConfig[] = [
      ['link', { rel: 'canonical', href: url }],
      ['meta', { property: 'og:type', content: isArticle ? 'article' : 'website' }],
      ['meta', { property: 'og:title', content: pageTitle }],
      ['meta', { property: 'og:description', content: pageDescription }],
      ['meta', { property: 'og:url', content: url }],
      ['meta', { property: 'og:image', content: DEFAULT_OG_IMAGE }],
      ['meta', { property: 'og:image:width', content: '1200' }],
      ['meta', { property: 'og:image:height', content: '630' }],
      ['meta', { name: 'twitter:title', content: pageTitle }],
      ['meta', { name: 'twitter:description', content: pageDescription }],
      ['meta', { name: 'twitter:image', content: DEFAULT_OG_IMAGE }]
    ]

    // 首页添加 JSON-LD 结构化数据
    if (page === '' || page === 'index.md') {
      head.push([
        'script',
        { type: 'application/ld+json' },
        JSON.stringify({
          '@context': 'https://schema.org',
          '@type': 'WebSite',
          name: SITE_NAME,
          url: SITE_URL,
          description: SITE_DESCRIPTION,
          author: { '@type': 'Person', name: 'Maple' },
          potentialAction: {
            '@type': 'SearchAction',
            target: `${SITE_URL}/?q={search_term_string}`,
            'query-input': 'required name=search_term_string'
          }
        })
      ])
    }

    return head
  },
  themeConfig: {
    logo: {
      light: '/logo-horizontal.svg',
      dark: '/logo-horizontal-dark.svg'
    },
    nav: [
      { text: '首页', link: '/' },
      { text: '使用指南', link: '/guide' },
      { text: '高级教程', link: '/advanced/' },
      { text: '提交插件', link: '/submit-plugin' },
      {
        text: '项目动态',
        items: [
          { text: '更新日志', link: '/update' },
          { text: '开发计划', link: '/todo' },
          { text: '归档说明', link: '/eol' }
        ]
      },
      {
        text: '支持',
        items: [
          { text: '付费技术支持', link: '/pay' },
          { text: '赞助和加群', link: '/sponsor' }
        ]
      },
      {
        text: '法律条款',
        items: [
          { text: '服务条款（TOS）', link: '/tos' },
          { text: '最终用户许可（ULA）', link: '/ula' }
        ]
      },
      { text: 'GitHub', link: 'https://github.com/PVE-Tools/PVE-Tools-9' }
    ],
    search: {
      provider: 'local'
    },
    lastUpdated: {
      text: '最后更新'
    },
    sidebar: [
      {
        text: '开始使用',
        items: [
          { text: '简介', link: '/guide' },
          { text: '功能特性', link: '/features' },
          { text: '提交插件', link: '/submit-plugin' },
          { text: '更新日志', link: '/update' },
          { text: '开发计划', link: '/todo' },
          { text: '常见问题', link: '/faq' },
          { text: '归档说明', link: '/eol' }
        ]
      },
      {
        text: '支持与赞助',
        items: [
          { text: '付费技术支持', link: '/pay' },
          { text: '赞助和加群', link: '/sponsor' }
        ]
      },
      {
        text: '法律条款',
        items: [
          { text: '服务条款（TOS）', link: '/tos' },
          { text: '最终用户许可（ULA）', link: '/ula' }
        ]
      },
      {
        text: '高级教程',
        items: [
          { text: '教程总览', link: '/advanced/' },
          { text: 'Intel 核显直通', link: '/advanced/gpu-passthrough' },
          { text: '核显虚拟化 SR-IOV', link: '/advanced/gpu-virtualization' },
          { text: 'CPU 性能调优', link: '/advanced/cpu-optimization' },
          { text: 'PVE 8 升级 9', link: '/advanced/pve-upgrade' },
          { text: '存储管理与休眠', link: '/advanced/storage-management' },
          { text: 'VM 备份/迁移/Cloud-Init', link: '/advanced/vm-backup-migration-cloudinit' },
          { text: '宿主机网络 / 防火墙 / IPv6', link: '/advanced/host-network-firewall-ipv6' },
          { text: '误操作后的数据恢复', link: '/advanced/data-recovery-after-mistake' },
          { text: 'NVIDIA vGPU 驱动说明', link: '/advanced/nvidia-vgpu-driver-notes' }
        ]
      }
    ],
    socialLinks: [
      { icon: 'github', link: 'https://github.com/PVE-Tools/PVE-Tools-9' },
      { icon: 'telegram', link: 'https://t.me/pvetools233' }
    ],
    footer: {
      message: ' Ciriu Networks |',
      copyright: '   | Copyright © 2024 - ∞ Maple'
    },
    // 自定义脚本源配置
    scriptSources: {
      cloudflare: 'https://pve.oowo.cc/PVE-Tools.sh',
      ghfast: 'https://ghfast.top/raw.githubusercontent.com/PVE-Tools/PVE-Tools-9/main/PVE-Tools.sh',
      github: 'https://raw.githubusercontent.com/PVE-Tools/PVE-Tools-9/main/PVE-Tools.sh',
      edgeone: '未上线'
    }
  }
})
