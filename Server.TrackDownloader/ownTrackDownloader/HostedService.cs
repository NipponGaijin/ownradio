using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using System;
using System.Threading;
using System.Threading.Tasks;

namespace ownTrackDownloader
{
    internal interface IScopedProcessingService
    {
        void DoWork();
    }

    internal class TrackDownloaderService : IScopedProcessingService
    {
        private readonly ILogger _logger;
        private DownloadEngine _engine = new DownloadEngine();

        public TrackDownloaderService(ILogger<TrackDownloaderService> logger)
        {
            _logger = logger;
        }

        public void DoWork()
        {
            _logger.LogInformation("TrackDownloader запускается.");

            _engine.Start(_logger);
        }
    }

    internal class HostedSrvice : IHostedService
    {
        private readonly ILogger _logger;

        public HostedSrvice(IServiceProvider services,
            ILogger<HostedSrvice> logger)
        {
            Services = services;
            _logger = logger;
        }

        public IServiceProvider Services { get; }

        public Task StartAsync(CancellationToken cancellationToken)
        {
            _logger.LogInformation(
                "HostedSrvice работает.");

            DoWork();

            return Task.CompletedTask;
        }

        private void DoWork()
        {
            _logger.LogInformation(
                "HostedSrvice работает.");

            using (var scope = Services.CreateScope())
            {
                var scopedProcessingService =
                    scope.ServiceProvider
                        .GetRequiredService<IScopedProcessingService>();

                scopedProcessingService.DoWork();
            }
        }

        public Task StopAsync(CancellationToken cancellationToken)
        {
            _logger.LogInformation(
                "HostedSrvice завершает работу.");

            return Task.CompletedTask;
        }
    }
}