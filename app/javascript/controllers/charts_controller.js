import {Controller} from "@hotwired/stimulus";
import ApexCharts from "apexcharts"
import humanizeDuration from "humanize-duration";

const formatTypes = ["number", "time"]
const chartTypes = ["area", "line", "stacked-bar", "polar-area"]

export default class extends Controller {
  static targets = ["chart"]

  static values = {
    type: String,
    format: {type: String, default: "number"},
    series: Array,
    annotations: Object,
    showXAxis: {type: Boolean, default: true},
    showYAxis: {type: Boolean, default: false},
    height: {type: String, default: "100%"},
  }

  initialize() {
    const chartType = this.typeValue

    if (!chartTypes.includes(chartType)) {
      console.error('Invalid chart type.')
      return;
    }

    if (!formatTypes.includes(this.formatValue)) {
      console.error('Invalid data format type.')
      return;
    }

    let series = this.seriesValue
    let chartOptions

    if (chartType === "area") {
      chartOptions = this.areaOptions(series)
    } else if (chartType === "line") {
      chartOptions = this.lineOptions(series)
    } else if (chartType === "stacked-bar") {
      chartOptions = this.stackedBarOptions(series)
    } else if (chartType === "polar-area") {
      chartOptions = this.polarAreaOptions(series[0])
    }

    this.chart = new ApexCharts(this.chartTarget, chartOptions);
    this.chart.render();
  }

  disconnect() {
    this.chart.destroy()
  }

  areaOptions(series) {
    let self = this;

    return {
      chart: {
        height: this.heightValue,
        maxWidth: "100%",
        width: "100%",
        type: "area",
        fontFamily: "Inter, sans-serif",
        dropShadow: {
          enabled: true,
          enabledSeries: [0],
          top: -2,
          left: 2,
          blur: 5,
          opacity: 0.1
        },
        toolbar: {
          show: false,
        },
      },
      tooltip: {
        enabled: true,
        x: {
          show: false,
        },
        y: {
          formatter(val) {
            if (self.__isTimeFormat()) {
              return self.__formatSeconds(val)
            } else {
              return val
            }
          },
        },
      },
      fill: {
        type: "gradient",
        gradient: {
          opacityFrom: 0.55,
          opacityTo: 0,
          shade: "#1C64F2",
          gradientToColors: ["#1C64F2"],
        },
      },
      dataLabels: {
        enabled: false,
      },
      stroke: {
        width: 3,
        curve: 'smooth',
      },
      grid: {
        show: true,
        strokeDashArray: 4,
        padding: {
          left: -5,
          right: 5,
        },
      },
      series: series,
      xaxis: {
        tickPlacement: 'between',
        labels: {
          show: this.showXAxisValue,
        },
        tooltip: {
          enabled: false
        },
        axisBorder: {
          show: false,
        },
        axisTicks: {
          show: false,
        },
      },
      yaxis: {
        show: false,
      },
      markers: {
        size: 3,
        hover: {
          sizeOffset: 2
        }
      }
    }
  }

  lineOptions(series) {
    let self = this;

    return {
      chart: {
        height: this.heightValue,
        maxWidth: "100%",
        type: "line",
        fontFamily: "Inter, sans-serif",
        dropShadow: {
          enabled: false,
        },
        toolbar: {
          show: false,
        },
      },
      tooltip: {
        enabled: true,
        x: {
          show: false,
        },
        y: {
          formatter(val) {
            if (self.__isTimeFormat()) {
              return self.__formatSeconds(val)
            } else {
              return val
            }
          },
        },
      },
      dataLabels: {
        enabled: false,
      },
      grid: {
        show: true,
        strokeDashArray: 4,
        padding: {
          left: 2,
          right: 2,
          top: -20
        },
      },
      series: series,
      stroke: {
        width: 3,
        curve: 'smooth'
      },
      xaxis: {
        tickPlacement: 'on',
        labels: {
          show: this.showXAxisValue,
          style: {
            fontFamily: "Inter, sans-serif",
            cssClass: 'text-xs font-normal fill-gray-500'
          },
          tooltip: {
            enabled: false
          },
        },
        axisBorder: {
          show: true,
        },
        axisTicks: {
          show: true,
        },
      },
      yaxis: {
        show: this.showYAxisValue,
      },
      annotations: this.annotationsValue,
      markers: {
        size: 3,
        hover: {
          sizeOffset: 2
        }
      }
    }
  }

  stackedBarOptions(series) {
    let self = this;

    return {
      series: series,
      chart: {
        type: "bar",
        stacked: true,
        fontFamily: "Inter, sans-serif",
        height: this.heightValue,
        toolbar: {
          show: false,
        },
      },
      plotOptions: {
        bar: {
          horizontal: false,
          rangeBarGroupRows: true,
        },
      },
      tooltip: {
        y: {
          formatter(val) {
            if (self.__isTimeFormat()) {
              return self.__formatSeconds(val)
            } else {
              return val
            }
          },
        },
      },
      states: {
        hover: {
          filter: {
            type: "darken",
            value: 1,
          },
        },
      },
      stroke: {
        show: true,
        width: 0,
        colors: ["transparent"],
      },
      grid: {
        show: true,
        strokeDashArray: 4,
        padding: {
          left: 2,
          right: 2,
          top: -14
        },
      },
      dataLabels: {
        enabled: true,
        style: {
          fontSize: "10px",
        },
        formatter(val, {w, seriesIndex, dataPointIndex}) {
          const yVal = w.config.series[seriesIndex].data[dataPointIndex].y

          if (self.__isTimeFormat()) {
            return self.__formatSeconds(yVal, true)
          } else {
            return val
          }
        },
      },
      legend: {
        show: true,
        fontSize: "11px"
      },
      xaxis: {
        show: true,
        labels: {
          show: true,
          style: {
            cssClass: 'text-xs font-normal fill-gray-500'
          }
        },
        axisBorder: {
          show: false,
        },
        axisTicks: {
          show: false,
        },
      },
      yaxis: {
        show: this.showYAxisValue,
      },
      fill: {
        opacity: 1,
      },
    }
  }

  polarAreaOptions(series) {
    let self = this;

    return {
      series: series["data"],
      colors: series["colors"],
      labels: series["labels"],
      chart: {
        type: "polarArea",
        fontFamily: "Inter, sans-serif",
      },
      stroke: {
        show: true,
        width: 0,
        colors: ["transparent"],
      },
      states: {
        hover: {
          filter: {
            type: "darken",
            value: 1,
          },
        },
      },
      fill: {
        opacity: 1,
      },
      yaxis: {
        show: this.showYAxisValue
      }
    }
  }

  __formatSeconds(seconds, isShort) {
    const ms = seconds * 1000
    if (isShort) {
      return humanizeDuration(ms, {
        round: false,
        largest: 1,
        maxDecimalPoints: 0,
        units: ["d", "h", "m"],
        language: "shortEn",
        languages: {shortEn: {h: () => "h", m: () => "m", d: () => "d", w: () => "w"}}
      })
    } else {
      return humanizeDuration(ms, {round: true, largest: 2, maxDecimalPoints: 1})
    }
  }

  __isTimeFormat() {
    return this.formatValue === "time"
  }
}
