import std;

int main() {
    constexpr std::size_t count = 1'000'000;
    constexpr int max_value = 100;

    std::mt19937 gen{std::random_device{}()};
    std::uniform_int_distribution dist{0, max_value};

    // ranges::generate берёт контейнер целиком, без пары begin/end.
    std::vector<int> numbers(count);
    std::ranges::generate(numbers, [&] { return dist(gen); });

    // reduce, а не accumulate: не обещает порядка обхода и потому может
    // векторизоваться. 0LL задаёт тип аккумулятора — с 0 это был бы int.
    const long long sum = std::reduce(numbers.begin(), numbers.end(), 0LL);
    const double mean = static_cast<double>(sum) / static_cast<double>(count);

    // ranges::minmax возвращает значения, а не итераторы, за один проход.
    const auto [lo, hi] = std::ranges::minmax(numbers);

    // nth_element не сортирует, а ставит на место только нужный элемент.
    const auto middle = numbers.begin() + static_cast<std::ptrdiff_t>(count / 2);
    std::ranges::nth_element(numbers, middle);

    std::println("среднее: {:.4f}   медиана: {}   диапазон: {}..{}", mean, *middle, lo, hi);
    std::println("");

    std::array<std::size_t, 10> buckets{};
    for (int v : numbers) {
        // Значений 101, а корзин 10, поэтому последняя забирает 90..100.
        const auto idx = std::min<std::size_t>(static_cast<std::size_t>(v) / 10, buckets.size() - 1);
        ++buckets[idx];
    }

    // Индекс приходится тащить через iota: views::enumerate в libc++ 21 ещё нет.
    for (auto i : std::views::iota(std::size_t{0}, buckets.size())) {
        // saturate_cast — из C++26. Обрезает по границам типа вместо UB
        // или молчаливого заворачивания.
        const auto width = std::saturate_cast<int>(buckets[i] / 2000);
        const std::size_t hi_label = (i + 1 == buckets.size()) ? 100 : i * 10 + 9;
        std::println("{:3}-{:3} {:>8} {}", i * 10, hi_label, buckets[i],
                     std::string(static_cast<std::size_t>(width), '#'));
    }

    return 0;
}
