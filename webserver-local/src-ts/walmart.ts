import vanillaPuppeteer from 'puppeteer'
import { addExtra } from 'puppeteer-extra'
import Stealth from 'puppeteer-extra-plugin-stealth'
import Adblocker from 'puppeteer-extra-plugin-adblocker'
import cheerio, { AnyNode, Cheerio, Element } from 'cheerio'
import _ from 'lodash'

export default async function (req : Express.Request, res: any) {
    console.log('Hello world')
    const store_selected = true
    try {
        const puppeteer = addExtra(vanillaPuppeteer)
        puppeteer.use(Stealth())
        puppeteer.use(Adblocker({ blockTrackers: true }))
        console.log('Launching')
        const page = await (
            await puppeteer.launch({
                executablePath:
                    'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
                headless: false,
                args: ['--enable-gpu', '--no-sandbox', '--mute-audio'],
            })
        ).newPage()
        page.setDefaultNavigationTimeout(10000)
        await page.goto('https://www.walmart.com/', {
            waitUntil: 'networkidle2',
            timeout: 10000,
        })
        if (!store_selected) {
            const fulfillment_banner =
                'button[data-automation-id="fulfillment-banner"]'
            const fulfillment_address =
                'div[data-automation-id="fulfillment-address"]>button'
            const store_zip_code = 'input[data-automation-id="store-zip-code"]'
            const first_store = 'label[data-automation-id="pickup-store"]>input'
            const save_button = 'button[data-automation-id="save-label"]'
            await page.waitForSelector(fulfillment_banner)
            await page.click(fulfillment_banner)
            await page.waitForSelector(fulfillment_address)
            await page.click(fulfillment_address)
            await page.waitForSelector(store_zip_code)
            await page.type(store_zip_code, '10040', { delay: 100 })
            await page.waitForSelector(first_store)
            await page.click(first_store)
            await page.click(save_button)

            // todo: save the list of stores
        } else {
            const header_input_search =
                'input[data-automation-id="header-input-search"]'
            await page.waitForSelector(header_input_search)
            await page.click(header_input_search)
            await page.waitForTimeout(500)
            await page.type(header_input_search, 'b')
            await page.waitForTimeout(500)
            await page.type(header_input_search, 'ananas', { delay: 100 })
            await page.keyboard.press('Enter')

            await page.waitForSelector('div[data-stack-index="0"]')

            const pageData = await page.content()

            const $ = cheerio.load(pageData, {
                scriptingEnabled: false,
            })
            const products_arr = _.map(
                $('div[data-stack-index="0"] section > div > div'),
                (item: Cheerio<Element>) => {
                    return {
                        spans: _.map(
                            cheerio(item)?.find('span'),
                            (item2: Cheerio<Element>) => cheerio(item2)?.text()
                        ),
                        price_divs: _.map(
                            cheerio(item)?.find(
                                'div[data-automation-id="product-price"]'
                            )[0]?.children,
                            (item2: Cheerio<Element>) => cheerio(item2)?.text()
                        ),
                    }
                }
            )
            console.log(products_arr)

            const products = _.filter(
                products_arr.map((product_obj: any) => {
                    const prod_spans = product_obj.spans
                    const ret = {
                        name: prod_spans[0],
                        price: prod_spans
                            .find((val: any) =>
                                val.startsWith('current price ')
                            )
                            ?.replace('current price ', ''),
                        price_by_weight: product_obj.price_divs.find(
                            (item: any) => item.includes('/')
                        ),
                        price_before: prod_spans
                            .find((val: any) => val.startsWith('Was '))
                            ?.replace('Was ', ''),
                        available: prod_spans.includes('today'),
                    }
                    if (!ret.price_by_weight) delete ret.price_by_weight
                    if (!ret.price_before) delete ret.price_before
                    return ret
                }),
                (item) => item?.name && item?.price && !!item?.available
            )
            console.log(products)
        }
    } catch (ex) {
        console.error(ex)
    }
    res.send('Hello World!')
}
