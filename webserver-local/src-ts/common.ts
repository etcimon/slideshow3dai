import type { Page } from 'puppeteer'

export interface TaskDataType {
    country: string
    zip: string
    url: string
    grocerName: string
}

export interface TaskHandlerArgs {
    page: Page
    data: TaskDataType
    worker: {
        id: number
    }
}
