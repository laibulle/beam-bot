// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

// Import Chart.js and plugins
import Chart from 'chart.js/auto';
import 'chartjs-adapter-luxon';
import { CandlestickController, CandlestickElement } from 'chartjs-chart-financial';
import zoomPlugin from 'chartjs-plugin-zoom';

// Register the candlestick elements and zoom plugin
Chart.register(CandlestickController, CandlestickElement, zoomPlugin);

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {
    PriceChart: {
      mounted() {
        this.chart = null;
        this.renderChart();
      },
      updated() {
        // Only update if the data has actually changed
        const newData = JSON.parse(this.el.dataset.chartData);
        if (this.chart && this.chart.data.datasets[0].data.length !== newData.length) {
          this.renderChart();
        }
      },
      destroyed() {
        if (this.chart) {
          this.chart.destroy();
          this.chart = null;
        }
      },
      renderChart() {
        try {
          const ctx = this.el.getContext('2d');
          const data = JSON.parse(this.el.dataset.chartData);

          // Process the data for the chart
          const candlesticks = data.map(d => {
            const timestamp = new Date(d.x).getTime();
            return {
              x: timestamp,
              o: Number(d.o),
              h: Number(d.h),
              l: Number(d.l),
              c: Number(d.c)
            };
          });
          
          if (this.chart) {
            this.chart.destroy();
          }

          this.chart = new Chart(ctx, {
            type: 'candlestick',
            data: {
              datasets: [{
                label: 'OHLC',
                data: candlesticks,
                color: {
                  up: '#22c55e',
                  down: '#ef4444',
                }
              }]
            },
            options: {
              responsive: true,
              maintainAspectRatio: false,
              animation: false,
              normalized: true,
              datasets: {
                candlestick: {
                  tooltip: {
                    callbacks: {
                      label: (ctx) => {
                        const point = ctx.raw;
                        return [
                          `Open: ${Number(point.o).toFixed(8)}`,
                          `High: ${Number(point.h).toFixed(8)}`,
                          `Low: ${Number(point.l).toFixed(8)}`,
                          `Close: ${Number(point.c).toFixed(8)}`
                        ];
                      }
                    }
                  }
                }
              },
              plugins: {
                legend: {
                  display: false
                },
                title: {
                  display: true,
                  text: 'Price History'
                },
                tooltip: {
                  enabled: true,
                  mode: 'point',
                  intersect: true,
                  callbacks: {
                    title: (items) => {
                      if (!items.length) return '';
                      const item = items[0];
                      const date = new Date(item.raw.x);
                      return date.toLocaleString();
                    }
                  }
                },
                zoom: {
                  pan: {
                    enabled: true,
                    mode: 'x'
                  },
                  zoom: {
                    wheel: {
                      enabled: true,
                    },
                    pinch: {
                      enabled: true
                    },
                    mode: 'x'
                  }
                }
              },
              scales: {
                x: {
                  type: 'time',
                  time: {
                    unit: 'day',
                    displayFormats: {
                      millisecond: 'HH:mm:ss.SSS',
                      second: 'HH:mm:ss',
                      minute: 'HH:mm',
                      hour: 'HH:mm',
                      day: 'MMM d',
                      week: 'MMM d',
                      month: 'MMM yyyy'
                    }
                  },
                  ticks: {
                    source: 'auto',
                    maxRotation: 0
                  }
                },
                y: {
                  position: 'right',
                  ticks: {
                    callback: value => Number(value).toFixed(8)
                  }
                }
              },
              interaction: {
                mode: 'point',
                intersect: true
              }
            }
          });
        } catch (error) {
          console.error('Error rendering chart:', error);
          if (this.chart) {
            this.chart.destroy();
            this.chart = null;
          }
        }
      }
    }
  }
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

