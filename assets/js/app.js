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
import { DateTime } from 'luxon';
import 'chartjs-adapter-luxon';
import { CandlestickController, CandlestickElement } from 'chartjs-chart-financial';

// Register the candlestick elements
Chart.register(CandlestickController, CandlestickElement);

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
        this.renderChart();
      },
      renderChart() {
        const ctx = this.el.getContext('2d');
        const data = JSON.parse(this.el.dataset.chartData);
        
        // Process the data for the chart
        const candlesticks = data.map(d => ({
          x: DateTime.fromMillis(new Date(d[0]).getTime()).toJSDate(),
          o: parseFloat(d[1]), // open
          h: parseFloat(d[2]), // high
          l: parseFloat(d[3]), // low
          c: parseFloat(d[4])  // close
        }));
        
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
            parsing: false,
            normalized: true,
            plugins: {
              legend: {
                display: false
              },
              title: {
                display: true,
                text: 'Price History'
              }
            },
            scales: {
              x: {
                type: 'time',
                time: {
                  unit: 'day',
                  displayFormats: {
                    day: 'MMM d'
                  }
                },
                ticks: {
                  source: 'auto',
                  maxRotation: 0
                }
              },
              y: {
                position: 'right',
                beginAtZero: false
              }
            }
          }
        });
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

