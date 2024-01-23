import { Cluster } from 'puppeteer-cluster'
import logger from './logger'

import vanillaPuppeteer from 'puppeteer'
import { addExtra } from 'puppeteer-extra'
import Stealth from 'puppeteer-extra-plugin-stealth'
import Adblocker from 'puppeteer-extra-plugin-adblocker'
import os from 'os'
import type { TaskHandlerArgs, TaskDataType } from './common'

import walmart from './walmart'

const cpuCoreCount = os.cpus().length
const isWin = process.platform === 'win32'
const isUbuntu = process.platform === 'linux'
let chromePath = ''
// todo: Find a better way to identify this
if (isWin)
    chromePath = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe'
else if (isUbuntu) chromePath = '/usr/bin/google-chrome'

export class WebWorker {
    cluster: Cluster<any, any> | undefined = undefined
    initialized: boolean = false
    clusterPromise: Promise<void | Cluster<any, any>> | undefined = undefined

    constructor() {
        const puppeteer = addExtra(vanillaPuppeteer)
        puppeteer.use(Stealth())
        puppeteer.use(Adblocker({ blockTrackers: true }))
        this.clusterPromise = Cluster.launch({
            puppeteer,
            puppeteerOptions: {
                executablePath: chromePath,
                headless: false,
                args: ['--enable-gpu', '--no-sandbox', '--mute-audio'],
            },
            concurrency: Cluster.CONCURRENCY_CONTEXT,
            maxConcurrency: cpuCoreCount,
        })
            .then((value: Cluster<any, any>) => {
                this.cluster = value
                this.cluster.task(this.taskHandler)
                return value
            })
            .catch((err: any) => {
                logger.error(err)
            })
            .finally(() => {
                this.initialized = true
            })
    }

    enqueue(data: TaskDataType) {
        return new Promise(async (resolve, reject) => {
            try {
                resolve(await this.cluster?.execute(data))
            } catch (ex: any) {
                reject(ex)
            }
        })
    }

    async taskHandler({ page, data }: TaskHandlerArgs) {
        page.setDefaultNavigationTimeout(10000)
        await page.goto(data.url, {
            waitUntil: 'networkidle2',
            timeout: 10000,
        })
        if (data.grocerName == 'walmart') {
            return await walmart(page, data)
        }
    }
}
