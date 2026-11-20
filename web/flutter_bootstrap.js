{{flutter_js}}
{{flutter_build_config}}
const config = {fontFallbackBaseUrl: 'fallback_fonts/'};
_flutter.loader.load({
  config,
  onEntrypointLoaded: async (initializer) => {
    const runner = await initializer.initializeEngine(config);
    await runner.runApp();
    document.getElementById('loading')?.remove();
  }
});
