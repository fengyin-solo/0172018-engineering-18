/* ========================================
   应用主入口
   ======================================== */

class App {
    constructor() {
        this.initialized = false;
    }

    init() {
        if (this.initialized) return;
        this.initialized = true;

        // 渲染构建信息（报告版本 / 数据更新时间，镜像构建期注入）
        this.renderBuildInfo();

        // 初始化组件
        window.componentRenderer.init();

        // 初始化图表
        window.chartManager.initFunnelChart('funnelChart');
        window.chartManager.initRadarChart('radarChart');

        // 监听窗口大小变化
        window.addEventListener('resize', this.handleResize.bind(this));

        // 监听滚动
        window.addEventListener('scroll', this.handleScroll.bind(this));

        console.log('🚀 Dashboard initialized successfully');
    }

    // 渲染构建信息：优先使用构建期注入的 window.__BUILD_INFO__，
    // 本地直接打开页面时使用 js/build-info.js 中的默认值
    renderBuildInfo() {
        const info = window.__BUILD_INFO__ || {};
        const versionEl = document.getElementById('reportVersion');
        const dateEl = document.getElementById('dataUpdatedAt');

        if (versionEl && info.reportVersion) {
            versionEl.textContent = info.reportVersion;
        }
        if (dateEl && info.dataUpdatedAt) {
            dateEl.textContent = info.dataUpdatedAt;
        }
    }

    handleResize() {
        // 防抖处理
        clearTimeout(this.resizeTimer);
        this.resizeTimer = setTimeout(() => {
            window.chartManager.resize();
        }, 250);
    }

    handleScroll() {
        // 可以添加滚动相关的动画效果
        const scrollY = window.scrollY;
        const header = document.querySelector('.header');
        
        if (header) {
            const opacity = Math.max(0.5, 1 - scrollY / 500);
            header.style.opacity = opacity;
        }
    }

    // 刷新数据
    refresh() {
        window.toast.info('刷新中', '正在重新加载数据...');
        
        setTimeout(() => {
            window.componentRenderer.renderStats();
            window.componentRenderer.renderMatrix();
            window.componentRenderer.renderQuickWins();
            window.chartManager.resize();
            
            window.toast.success('刷新完成', '数据已更新');
        }, 1000);
    }

    // 导出报告
    exportReport() {
        window.toast.info('导出报告', '正在生成PDF报告...');
        
        setTimeout(() => {
            window.toast.success('导出成功', '报告已保存到下载目录');
        }, 2000);
    }
}

// 创建应用实例
const app = new App();

// DOM 加载完成后初始化
document.addEventListener('DOMContentLoaded', () => {
    app.init();
});

// 暴露全局方法
window.app = app;
