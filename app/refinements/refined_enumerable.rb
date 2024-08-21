module RefinedEnumerable
  refine Enumerable do
    def vmax_by(attr)
      reject { |item| item&.public_send(attr).nil? }
        .max_by { |item| item.public_send(attr) }
        &.public_send(attr)
    end

    def vmin_by(attr)
      reject { |item| item&.public_send(attr).nil? }
        .min_by { |item| item.public_send(attr) }
        &.public_send(attr)
    end
  end
end
