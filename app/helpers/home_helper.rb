module HomeHelper
  def availability_color_class(rate)
    case rate
    when 100
      { text: "text-red-600 dark:text-red-400", bg: "bg-red-500" }
    when 80..99
      { text: "text-orange-600 dark:text-orange-400", bg: "bg-orange-500" }
    when 50..79
      { text: "text-yellow-600 dark:text-yellow-400", bg: "bg-yellow-500" }
    else
      { text: "text-green-600 dark:text-green-400", bg: "bg-green-500" }
    end
  end
end
